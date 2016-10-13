module SheetsDB
  class Worksheet
    class Row
      class AttributeAlreadyRegisteredError < StandardError; end
      class AssociationAlreadyRegisteredError < StandardError; end

      class << self
        attr_reader :attribute_definitions, :association_definitions

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@attribute_definitions, attribute_definitions)
          subclass.instance_variable_set(:@association_definitions, association_definitions)
        end

        def attribute(name, type: String, multiple: false)
          register_attribute(name, type: type, multiple: multiple, association: false)

          define_method(name) do
            get_modified_attribute(name) || get_persisted_attribute(name)
          end

          define_method("#{name}=") do |value|
            stage_attribute_modification(name, value)
          end
        end

        def has_association(name, from_collection:, key:, multiple: false)
          register_attribute(name, from_collection: from_collection, key: key, multiple: multiple, association: true)

          define_method(name) do
            @loaded_associations[name] ||= begin
              response = spreadsheet.find_associations_by_ids(from_collection, Array(send(key)))
              multiple ? response : response.first
            end
          end

          define_method("#{name}=") do |value|
            assignment_value = multiple ? value.map(&:id) : value.id
            send("#{key}=", assignment_value)
            @loaded_associations[name] = value
          end
        end

        def has_one(name, from_collection:, key:)
          has_association(name, from_collection: from_collection, key: key, multiple: false)
        end

        def has_many(name, from_collection:, key:)
          has_association(name, from_collection: from_collection, key: key, multiple: true)
        end

        def belongs_to_association(name, from_collection:, foreign_key:, multiple: false)
          register_attribute(name, from_collection: from_collection, foreign_key: foreign_key, multiple: multiple, association: true)

          define_method(name) do
            @loaded_associations[name] ||= begin
              response = spreadsheet.find_associations_by_attribute(from_collection, foreign_key, id)
              multiple ? response : response.first
            end
          end

          define_method("#{name}=") do |value|
            Array(value).each do |foreign_item|
              remote_definition = spreadsheet.send(from_collection).attribute_definitions[foreign_key]
              assignment_value = if remote_definition[:multiple]
                (foreign_item.send(foreign_key) || []).concat([id])
              else
                id
              end
              foreign_item.send("#{foreign_key}=", assignment_value)
            end
            @loaded_associations[name] = value
          end
        end

        def belongs_to_one(name, from_collection:, foreign_key:)
          belongs_to_association(name, from_collection: from_collection, foreign_key: foreign_key, multiple: false)
        end

        def belongs_to_many(name, from_collection:, foreign_key:)
          belongs_to_association(name, from_collection: from_collection, foreign_key: foreign_key, multiple: true)
        end

        def register_attribute(name, **options)
          @attribute_definitions ||= {}
          if @attribute_definitions.fetch(name, nil)
            raise AttributeAlreadyRegisteredError
          end
          @attribute_definitions[name] = options
        end
      end

      attr_reader :worksheet, :row_position, :loaded_attributes, :loaded_associations

      def initialize(worksheet:, row_position:)
        @worksheet = worksheet
        @row_position = row_position
        @loaded_attributes = {}
        @loaded_associations = {}
      end

      def get_modified_attribute(name)
        loaded_attributes.fetch(name, {}).
          fetch(:changed, nil)
      end

      def get_persisted_attribute(name)
        loaded_attributes[name] ||= {}
        loaded_attributes[name][:original] ||= begin
          attribute_definition = self.class.attribute_definitions.fetch(name, {})
          worksheet.attribute_at_row_position(name,
            row_position: row_position,
            type: attribute_definition[:type],
            multiple: attribute_definition[:multiple]
          )
        end
      end

      def stage_attribute_modification(name, value)
        loaded_attributes[name] ||= {}
        loaded_attributes[name][:changed] = value
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
        @loaded_attributes = {}
        @loaded_associations = {}
      end

      def staged_attributes
        loaded_attributes.each_with_object({}) { |(key, value), hsh|
          next unless value
          hsh[key] = value[:changed] if value[:changed]
          hsh
        }
      end

      def spreadsheet
        worksheet.spreadsheet
      end

      def attributes
        get_all_attributes do |options|
          !options.fetch(:association, false)
        end
      end

      def associations
        get_all_attributes do |options|
          options.fetch(:association, false)
        end
      end

      def get_all_attributes(&block)
        self.class.attribute_definitions.each_with_object({}) { |(name, options), memo|
          memo[name] = send(name) if block.call(options)
          memo
        }
      end

      def to_hash(depth: 0)
        hashed_associations = if depth > 0
          Hash[
            associations.map { |name, association|
              association_hash = if association.is_a?(Array)
                association.map { |item| item.to_hash(depth: depth - 1) }
              else
                association.to_hash(depth: depth - 1)
              end
              [name, association_hash]
            }
          ]
        else
          {}
        end
        attributes.merge(hashed_associations)
      end
    end
  end
end