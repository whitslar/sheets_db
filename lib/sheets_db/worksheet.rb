require_relative "worksheet/column"
require_relative "worksheet/row"

module SheetsDB
  class Worksheet
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

    def columns
      @columns ||= begin
        {}.tap { |directory|
          google_drive_resource.rows.first.each_with_index do |name, i|
            unless name == ""
              directory[name.to_sym] = Column.new(name: name.to_sym, column_position: i + 1)
            end
          end
        }
      end
    end

    def attribute_at_row_position(column_name, row_position:, type: String, multiple: false)
      column = columns[column_name]
      raw_value = google_drive_resource[row_position, column.column_position]
      if multiple
        raw_values = raw_value.split(/,\s*/)
        raw_values.map { |value| convert_value(value, type) }
      else
        convert_value(raw_value, type)
      end
    end

    def update_attributes_at_row_position(staged_attributes, row_position:)
      staged_attributes.each do |name, value|
        column = columns[name]
        google_drive_resource[row_position, column.column_position] = value
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

    def reload!
      google_drive_resource.reload
    end

    def convert_value(raw_value, type)
      return nil if raw_value == ""
      case type.to_s
      when "Integer"
        raw_value.to_i
      else
        raw_value
      end
    end
  end
end