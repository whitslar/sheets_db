require_relative "worksheet/column"
require_relative "worksheet/row"

module SheetsDB
  class Worksheet
    include Enumerable

    attr_reader :worksheet, :type

    def initialize(worksheet:, type:)
      @worksheet = worksheet
      @type = type
    end

    def ==(other)
      other.is_a?(self.class) &&
        other.worksheet == worksheet &&
        other.type == type
    end

    def columns
      @columns ||= worksheet.rows.first.each_with_index.map { |name, i|
        name == "" ? nil :
          Column.new(name: name.to_sym, column_position: i + 1)
      }.compact
    end

    def data_rows
      worksheet.rows.drop(1)
    end

    def each
      return to_enum(:each) unless block_given?
      data_rows.each_with_index do |row, i|
        yield type.new(worksheet: self, row_position: i + 2, **arguments_from_row(row))
      end
    end

    def all
      to_a
    end

    def find_by_id(id)
      detect { |model| model.id == id }
    end

    def arguments_from_row(row)
      relevant_row_indices = columns.map(&:column_position).map { |pos| pos - 1 }
      Hash[columns.map(&:name).zip(row.values_at(*relevant_row_indices))]
    end
  end
end