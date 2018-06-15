require 'bigdecimal/util'
require_relative "worksheet/column"
require_relative "worksheet/row"

module SheetsDB
  class Worksheet
    class ColumnNotFoundError < StandardError; end

    include Enumerable

    attr_reader :spreadsheet, :worksheet_title, :google_drive_resource, :synchronizing

    def initialize(spreadsheet:, google_drive_resource:, type: nil)
      @spreadsheet = spreadsheet
      @google_drive_resource = google_drive_resource
      @worksheet_title = google_drive_resource.title
      @type = type
      @synchronizing = true
    end

    def set_up!
      if google_drive_resource.num_rows == 0
        registered_column_names = attribute_definitions.map { |name, definition| definition[:column_name] }
        write_matrix!([registered_column_names])
      end
      self
    end

    def type
      @type || @generated_type ||= begin
        Class.new(Row).tap { |generated_type_class|
          column_names.each do |name|
            generated_type_class.attribute name.to_sym
          end
        }
      end
    end

    def ==(other)
      other.is_a?(self.class) &&
        other.google_drive_resource == google_drive_resource &&
        other.type == type
    end

    alias_method :eql?, :==

    def hash
      [self.class, google_drive_resource, type].hash
    end

    def columns
      @columns ||= begin
        {}.tap { |directory|
          header_row = google_drive_resource.rows.first || []
          header_row.each_with_index do |name, i|
            unless name == ""
              directory[name] = Column.new(name: name, column_position: i + 1)
            end
          end
        }
      end
    end

    def column_names
      columns.keys
    end

    def attribute_definitions
      type.attribute_definitions
    end

    def get_definition_and_column(attribute_name)
      column_name = first_existing_column_name(attribute_name)
      [
        attribute_definitions.fetch(attribute_name),
        column_name && columns[column_name.to_s]
      ]
    end

    def first_existing_column_name(attribute_name)
      attribute_definition = attribute_definitions.fetch(attribute_name)
      [
        attribute_definition.fetch(:column_name, attribute_name),
        attribute_definition.fetch(:aliases, [])
      ].flatten.detect { |name|
        columns.key?(name.to_s)
      }
    end

    def value_if_column_missing(attribute_definition)
      unless attribute_definition[:if_column_missing]
        raise ColumnNotFoundError, attribute_definition[:column_name]
      end
      instance_exec(&attribute_definition[:if_column_missing])
    end

    def attribute_at_row_position(attribute_name, row_position)
      attribute_definition, column = get_definition_and_column(attribute_name)
      return value_if_column_missing(attribute_definition) unless column
      raw_value = read_value_from_google_drive_resource(
        dimensions: [row_position, column.column_position],
        attribute_definition: attribute_definition
      )
    end

    def read_value_from_google_drive_resource(dimensions:, attribute_definition:)
      raw_value = case attribute_definition[:type].to_s
        when "DateTime"
          google_drive_resource.input_value(*dimensions)
        else
          google_drive_resource[*dimensions]
      end
      if attribute_definition[:multiple]
        raw_value.split(/,\s*/).map { |value| convert_value(value, attribute_definition) }
      else
        convert_value(raw_value, attribute_definition)
      end
    end

    def update_attributes_at_row_position(staged_attributes, row_position:)
      staged_attributes.each do |attribute_name, value|
        update_attribute_at_row_position(
          attribute_name: attribute_name,
          value: value,
          row_position: row_position
        )
      end
      synchronize! if synchronizing
    end

    def update_attribute_at_row_position(attribute_name:, value:, row_position:)
      attribute_definition, column = get_definition_and_column(attribute_name)
      raise ColumnNotFoundError, column unless column
      assignment_value = attribute_definition[:multiple] ? value.join(",") : value
      google_drive_resource[row_position, column.column_position] = assignment_value
    end

    def next_available_row_position
      google_drive_resource.num_rows + 1
    end

    def new(**attributes)
      type.new(worksheet: self, row_position: nil).tap { |row|
        row.stage_attributes(attributes)
      }
    end

    def create!(**attributes)
      new(**attributes).save!
    end

    def import!(attribute_sets)
      transaction do
        attribute_sets.each do |attributes|
          create!(**attributes)
        end
      end
    end

    def each
      return to_enum(:each) unless block_given?
      (google_drive_resource.num_rows - 1).times do |i|
        yield type.new(worksheet: self, row_position: i + 2)
      end
    end

    def all
      to_a
    end

    def find_by_id(id)
      find_by_ids([id]).first
    end

    def find_by_ids(ids)
      result = []
      each do |model|
        break if result.count == ids.count
        if ids.include?(model.id)
          result << model
        end
      end
      result
    end

    def find_by_attribute(attribute_name, value)
      definition = attribute_definitions[attribute_name]
      select { |item|
        attribute = item.send(attribute_name)
        definition[:multiple] ? attribute.include?(value) : attribute == value
      }
    end

    def reload!
      @columns = nil
      @existing_raw_data = nil
      @generated_type = nil
      google_drive_resource.reload
      self
    end

    def convert_to_boolean(raw_value)
      return nil if raw_value.nil?
      trues = ["y", "yes", "true", "1"]
      falses = ["n", "no", "false", "0"]
      return true if trues.include?(raw_value.downcase)
      return false if falses.include?(raw_value.downcase)
    end

    def convert_value(raw_value, attribute_definition)
      raw_value = raw_value.strip if attribute_definition.fetch(:strip, true)
      return nil if raw_value == ""
      converted_value = case attribute_definition[:type].to_s
      when "Integer"
        raw_value.to_i
      when "Decimal"
        raw_value.to_d
      when "DateTime"
        DateTime.strptime(raw_value, "%m/%d/%Y %H:%M:%S")
      when "Boolean"
        convert_to_boolean(raw_value)
      else
        raw_value
      end
      attribute_definition[:transform] ?
        attribute_definition[:transform].call(converted_value) :
        converted_value
    end

    def enable_synchronization!
      @synchronizing = true
    end

    def disable_synchronization!
      @synchronizing = false
    end

    def transaction
      disable_synchronization!
      yield
      synchronize!
    ensure
      enable_synchronization!
    end

    def delete_google_drive_resource!
      google_drive_resource.delete
      @google_drive_resource = nil
      spreadsheet.reload!
    end

    def truncate!
      clear_google_drive_resource!
      set_up!
      reload!
    end

    def write_matrix(matrix, rewrite: false, save: false)
      clear_google_drive_resource if rewrite
      google_drive_resource.update_cells(1, 1, matrix)
      synchronize! if save
      self
    end

    def write_matrix!(matrix, **options)
      write_matrix(matrix, **options.merge(save: true))
    end

    def write_raw_data(data, **options)
      raise ArgumentError, "mismatched keys" if data.map(&:keys).uniq.count > 1

      write_matrix(data.map(&:values).prepend(data.first.keys), **options)
    end

    def write_raw_data!(data, **options)
      write_raw_data(data, **options.merge(save: true))
    end

    def clear_google_drive_resource(save: false)
      empty_matrix = Array.new(google_drive_resource.num_rows, Array.new(google_drive_resource.num_cols))
      write_matrix(empty_matrix, save: save)
    end

    def clear_google_drive_resource!
      clear_google_drive_resource(save: true)
    end

    def synchronize!
      google_drive_resource.synchronize
      @existing_raw_data = nil
      self
    end

    def existing_raw_data
      @existing_raw_data ||= begin
        rows = google_drive_resource.rows
        rows.drop(1).map { |row| Hash[rows.first.zip(row)] }
      end
    end
  end
end
