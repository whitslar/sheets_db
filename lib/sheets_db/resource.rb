module SheetsDB
  class Resource
    class ResourceTypeMismatchError < StandardError; end

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
    end

    extend Forwardable
    def_delegators :google_drive_resource, :id, :name

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
