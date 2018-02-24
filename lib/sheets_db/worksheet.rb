require_relative "worksheet/column"
require_relative "worksheet/row"

module SheetsDB
  class Worksheet
    class ColumnNotFoundError < StandardError; end

    include Enumerable

    attr_reader :spreadsheet, :google_drive_resource, :type

    def initialize(spreadsheet:, google_drive_resource:, type:)
      @spreadsheet = spreadsheet
      @google_drive_resource = google_drive_resource
      @type = type
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
          google_drive_resource.rows.first.each_with_index do |name, i|
            unless name == ""
              directory[name] = Column.new(name: name, column_position: i + 1)
            end
          end
        }
      end
    end

    def attribute_definitions
      type.attribute_definitions
    end

    def get_definition_and_column(attribute_name)
      attribute_definition = attribute_definitions.fetch(attribute_name, {})
      column_name = attribute_definition.fetch(:column_name, attribute_name.to_s)
      raise ColumnNotFoundError, column_name if columns[column_name].nil?
      [
        attribute_definition,
        columns[column_name]
      ]
    end

    def attribute_at_row_position(attribute_name, row_position)
      attribute_definition, column = get_definition_and_column(attribute_name)
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
        attribute_definition, column = get_definition_and_column(attribute_name)
        assignment_value = attribute_definition[:multiple] ? value.join(",") : value
        google_drive_resource[row_position, column.column_position] = assignment_value
      end
      google_drive_resource.synchronize
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
      google_drive_resource.reload
    end

    def convert_value(raw_value, attribute_definition)
      raw_value = raw_value.strip if attribute_definition.fetch(:strip, true)
      return nil if raw_value == ""
      converted_value = case attribute_definition[:type].to_s
      when "Integer"
        raw_value.to_i
      when "DateTime"
        DateTime.strptime(raw_value, "%m/%d/%Y %H:%M:%S")
      when "Boolean"
        { "TRUE" => true, "FALSE" => false }.fetch(raw_value.upcase, nil)
      else
        raw_value
      end
      attribute_definition[:transform] ?
        attribute_definition[:transform].call(converted_value) :
        converted_value
    end
  end
end
