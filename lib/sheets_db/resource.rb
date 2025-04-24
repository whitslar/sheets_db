module SheetsDB
  class Resource
    class ResourceTypeMismatchError < StandardError; end
    class CollectionTypeAlreadyRegisteredError < StandardError; end
    class ChildResourceNotFoundError < StandardError; end

    class << self
      attr_reader :resource_type

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@resource_type, @resource_type)
      end

      def set_resource_type(resource_type)
        @resource_type = resource_type
      end

      def find(id_or_url, session: SheetsDB::Session.default)
        find_by_url(id_or_url, session: session)
      rescue SheetsDB::Session::InvalidGoogleDriveUrlError
        find_by_id(id_or_url, session: session)
      end

      def find_by_url(url, session: SheetsDB::Session.default)
        wrap_google_drive_resource(session.raw_file_by_url(url))
      end

      def find_by_id(id, session: SheetsDB::Session.default)
        wrap_google_drive_resource(session.raw_file_by_id(id))
      end

      def wrap_google_drive_resource(google_drive_resource)
        if resource_type && !google_drive_resource.is_a?(resource_type)
          fail(
            ResourceTypeMismatchError,
            "The file #{google_drive_resource.human_url} is not a #{resource_type}"
          )
        end
        new(google_drive_resource)
      end

      def belongs_to_many(resource, class_name:)
        register_association(resource, class_name: class_name, resource_type: :parents)
        define_method(resource) do
          @associated_resources ||= {}
          @associated_resources[resource] ||= google_drive_resource.parents.map { |id|
            Support.constantize(class_name).find_by_id(id)
          }
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

      def association_methods_for_type(type)
        raise ArgumentError unless %i[spreadsheet worksheet subcollection].include?(type)

        google_type = type == :spreadsheet ? :file : type
        create_prefix = type == :worksheet ? :add : :create

        OpenStruct.new(find: :"#{google_type}_by_title", create: :"#{create_prefix}_#{type}")
      end
    end

    extend Forwardable
    def_delegators :google_drive_resource, :id, :name, :human_url
    def_delegator :google_drive_resource, :created_time, :created_at
    def_delegator :google_drive_resource, :modified_time, :updated_at

    attr_reader :google_drive_resource

    def initialize(google_drive_resource)
      @google_drive_resource = google_drive_resource
    end

    def reload!
      @associated_resources = nil
      @anonymous_resources = nil
      google_drive_resource.reload_metadata
    end

    def delete!
      google_drive_resource.delete
    end

    def ==(other)
      other.is_a?(self.class) &&
        other.google_drive_resource == google_drive_resource
    end

    alias_method :eql?, :==

    def hash
      [self.class, google_drive_resource].hash
    end

    def base_attributes
      {
        id: id,
        name: name,
        created_at: created_at,
        updated_at: updated_at
      }
    end

    def find_child_google_drive_resource_by(type:, title:, create: false)
      association_methods = self.class.association_methods_for_type(type)
      child_resource = google_drive_resource.public_send(association_methods.find, title)
      child_resource ||= google_drive_resource.public_send(association_methods.create, title) if create
      raise ChildResourceNotFoundError, [self, type, title] if child_resource.nil?

      child_resource
    end
  end
end
