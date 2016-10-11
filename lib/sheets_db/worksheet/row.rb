module SheetsDB
  class Worksheet
    class Row
      class << self
        attr_reader :attribute_definitions, :association_definitions

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@attribute_definitions, attribute_definitions)
          subclass.instance_variable_set(:@association_definitions, association_definitions)
        end

        def attribute(name, type: String, collection: false)
          @attribute_definitions ||= {}
          @attribute_definitions[name] = { type: type, collection: collection }

          define_method(name) do
            get_modified_attribute(name) || get_persisted_attribute(name)
          end

          define_method("#{name}=") do |value|
            stage_attribute_modification(name, value)
          end
        end

        def has_one(name, from_collection:, key:)
          @association_definitions ||= {}
          @association_definitions[name] = { from_collection: from_collection, key: key }

          define_method(name) do
            @associations[name] ||= worksheet.spreadsheet.send(from_collection).find_by_id(send(key))
          end

          define_method("#{name}=") do |value|
            send("#{key}=", value.id)
            @associations[name] ||= value
          end
        end
      end

      attr_reader :worksheet, :row_position, :attributes

      attribute :id, type: Integer

      def initialize(worksheet:, row_position:)
        @worksheet = worksheet
        @row_position = row_position
        @attributes = {}
        @associations = {}
      end

      def get_modified_attribute(name)
        attributes.fetch(name, {}).
          fetch(:changed, nil)
      end

      def get_persisted_attribute(name)
        attributes[name] ||= {}
        attributes[name][:original] ||= begin
          attribute_definition = self.class.attribute_definitions.fetch(name, {})
          raw_value = worksheet.attribute_at_row_position(name, row_position: row_position)
          if attribute_definition[:collection]
            raw_values = raw_value.split(/,\s*/)
            raw_values.map { |value| convert_value(value, attribute_definition[:type]) }
          else
            convert_value(raw_value, attribute_definition[:type])
          end
        end
      end

      def stage_attribute_modification(name, value)
        attributes[name] ||= {}
        attributes[name][:changed] = value
      end

      def reload!
        worksheet.reload!
        @attributes = {}
        @associations = {}
      end

      def save!
        worksheet.columns.each do |name, column|
          new_value = attributes[name] && attributes[name][:changed]
          if new_value
            worksheet.google_drive_resource[row_position, column.column_position] = new_value
          end
        end
        worksheet.google_drive_resource.synchronize
        @attributes = {}
        @associations = {}
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