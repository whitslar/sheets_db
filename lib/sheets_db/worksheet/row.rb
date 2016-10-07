module SheetsDB
  class Worksheet
    class Row
      class << self
        def column(name, type: String, collection: false)
          define_method(name) do
            raw_value = instance_variable_get(:"@#{name}")
            if collection
              raw_values = raw_value.split(/,\s*/)
              raw_values.map { |value| convert_value(value, type) }
            else
              convert_value(raw_value, type)
            end
          end
        end
      end

      column :id, type: Integer

      def initialize(worksheet:, row_position:, **attributes)
        @worksheet = worksheet
        @row_position = row_position
        attributes.each do |name, value|
          instance_variable_set(:"@#{name}", value)
        end
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
end