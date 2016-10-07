module SheetsDB
  class Worksheet
    class Column
      attr_reader :name, :column_position

      def initialize(name:, column_position:)
        @name = name
        @column_position = column_position
      end

      def ==(other)
        other.is_a?(self.class) &&
          other.name == name &&
          other.column_position == column_position
      end
    end
  end
end