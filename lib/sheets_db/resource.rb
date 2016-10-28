module SheetsDB
  class Resource
    class ResourceTypeMismatchError < StandardError; end
    class CollectionTypeAlreadyRegisteredError < StandardError; end

    class << self
      attr_reader :resource_type

      def set_resource_type(resource_type)
        @resource_type = resource_type
      end

      def find_by_id(id, session: SheetsDB::Session.default)
        google_drive_resource = session.raw_file_by_id(id)
        if @resource_type && !google_drive_resource.is_a?(@resource_type)
          fail(ResourceTypeMismatchError, "The file with id #{id} is not a #{@resource_type}")
        end
        new(google_drive_resource)
      end

      def belongs_to_many(resource, class_name:)
        register_association(resource, class_name: class_name, resource_type: :parents)
        define_method(resource) do
          result = instance_variable_get(:"@#{resource}")
          result || instance_variable_set(:"@#{resource}",
            google_drive_resource.parents.map { |id| Support.constantize(class_name).find_by_id(id) }
          )
        end
      end

      def register_association(resource, class_name:, resource_type:)
        @associations ||= {}
        if @associations.values.any? { |value| value[:resource_type] == resource_type }
          raise CollectionTypeAlreadyRegisteredError
        end
        @associations[resource] = {
          resource_type: resource_type,
          class_name: class_name
        }
      end
    end

    extend Forwardable
    def_delegators :google_drive_resource, :id, :name
    def_delegator :google_drive_resource, :created_time, :created_at
    def_delegator :google_drive_resource, :modified_time, :updated_at

    attr_reader :google_drive_resource

    def initialize(google_drive_resource)
      @google_drive_resource = google_drive_resource
    end

    def ==(other)
      other.is_a?(self.class) &&
        other.google_drive_resource == google_drive_resource
    end
  end
end
