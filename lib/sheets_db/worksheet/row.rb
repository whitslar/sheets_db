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
            @associations[name] ||= spreadsheet.find_association_by_id(from_collection, send(key))
          end

          define_method("#{name}=") do |value|
            send("#{key}=", value.id)
            @associations[name] ||= value
          end
        end
      end

      attr_reader :worksheet, :row_position, :attributes, :associations

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
        reset_attributes_and_associations_cache
      end

      def save!
        worksheet.update_attributes_at_row_position(staged_attributes, row_position: row_position)
        reset_attributes_and_associations_cache
      end

      def reset_attributes_and_associations_cache
        @attributes = {}
        @associations = {}
      end

      def staged_attributes
        attributes.each_with_object({}) { |(key, value), hsh|
          next unless value
          hsh[key] = value[:changed] if value[:changed]
          hsh
        }
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

      def spreadsheet
        worksheet.spreadsheet
      end
    end
  end
end