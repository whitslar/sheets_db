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

    def attribute_at_row_position(column_name, row_position:)
      column = columns[column_name]
      google_drive_resource[row_position, column.column_position]
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
      detect { |model| model.id == id }
    end

    def reload!
      google_drive_resource.reload
    end
  end
end