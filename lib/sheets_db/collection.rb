module SheetsDB
  class Collection < Resource
    set_resource_type GoogleDrive::Collection

    class << self
      def has_many(resource, class_name:, resource_type: :subcollections)
        unless [:subcollections, :spreadsheets].include?(resource_type)
          raise ArgumentError, "resource_type must be :subcollections or :spreadsheets"
        end
        register_association(resource, class_name: class_name, resource_type: resource_type)
        define_method(resource) do
          @associated_resources ||= {}
          @associated_resources[resource] ||= google_drive_resource.send(resource_type).map { |raw|
            Support.constantize(class_name).new(raw)
          }
        end
      end
    end

    %i[
      spreadsheet
      subcollection
    ].each do |child_resource_type|
      define_method :"google_drive_#{child_resource_type}_by_title" do |title, **kwargs|
        find_child_google_drive_resource_by(type: child_resource_type, title: title, **kwargs)
      end
    end

    def spreadsheets
      @anonymous_resources ||= {}
      @anonymous_resources[:spreadsheets] ||=
        google_drive_resource.spreadsheets.map { |raw| Spreadsheet.new(raw) }
    end

    def collections
      @anonymous_resources ||= {}
      @anonymous_resources[:collections] ||=
        google_drive_resource.subcollections.map { |raw| Collection.new(raw) }
    end
  end
end
