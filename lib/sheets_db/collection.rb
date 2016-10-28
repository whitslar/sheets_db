module SheetsDB
  class Collection < Resource
    set_resource_type GoogleDrive::Collection

    def self.has_many(resource, class_name:, resource_type: :subcollections)
      unless [:subcollections, :spreadsheets].include?(resource_type)
        raise ArgumentError, "resource_type must be :subcollections or :spreadsheets"
      end
      register_association(resource, class_name: class_name, resource_type: resource_type)
      define_method(resource) do
        result = instance_variable_get(:"@#{resource}")
        result || instance_variable_set(:"@#{resource}",
          google_drive_resource.send(resource_type).map { |raw| Support.constantize(class_name).new(raw) }
        )
      end
    end
  end
end