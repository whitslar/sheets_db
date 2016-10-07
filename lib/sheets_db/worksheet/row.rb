module SheetsDB
  class Worksheet
    class Row
      def initialize(worksheet:, row_position:, **attributes)
        @worksheet = worksheet
        @row_position = row_position
        attributes.each do |name, value|
          instance_variable_set(:"@#{name}", value)
        end
      end
    end
  end
end