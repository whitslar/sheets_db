module SheetsDB
  class Collection < Resource
    class CollectionTypeAlreadyRegisteredError < StandardError; end

    set_resource_type GoogleDrive::Collection

    def self.has_many(resource, type:)
      retrieval_method = association_retrieval_method_for_type(type)
      register_association(resource, type: type, retrieval_method: retrieval_method)
      define_method(resource) do
        associations = google_drive_resource.send(retrieval_method)
        associations.map { |raw| type.new(raw) }
      end
    end

    def self.register_association(resource, type:, retrieval_method:)
      @associations ||= {}
      if @associations.fetch(retrieval_method, nil)
        raise CollectionTypeAlreadyRegisteredError
      end
      @associations[retrieval_method] = [resource, type]
    end

    def self.association_retrieval_method_for_type(type)
      if type <= Collection
        :subcollections
      elsif type <= Spreadsheet
        :spreadsheets
      else
        raise ArgumentError, "Type must be a class inheriting from Spreadsheet or Collection"
      end
    end
  end
end