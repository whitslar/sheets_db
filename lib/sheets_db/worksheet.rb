module SheetsDB
  class Worksheet
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

    def column_names
      worksheet.rows.first.map(&:to_sym)
    end

    def data_rows
      worksheet.rows.drop(1)
    end

    def all
      data_rows.map { |row|
        type.new(worksheet: self, **arguments_from_row(row))
      }
    end

    def arguments_from_row(row)
      Hash[column_names.zip(row)].reject { |k,v| k == :"" }
    end
  end
end