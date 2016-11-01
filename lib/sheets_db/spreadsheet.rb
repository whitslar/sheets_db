module SheetsDB
  class Spreadsheet < Resource
    class WorksheetAssociationAlreadyRegisteredError < StandardError; end

    set_resource_type GoogleDrive::Spreadsheet

    def self.has_many(resource, worksheet_name:, class_name:)
      register_worksheet_association(resource, worksheet_name: worksheet_name, class_name: class_name)
      define_method(resource) do
        @worksheets ||= {}
        @worksheets[resource] ||= Worksheet.new(
          spreadsheet: self,
          google_drive_resource: google_drive_resource.worksheet_by_title(worksheet_name),
          type: Support.constantize(class_name)
        )
      end
    end

    def self.register_worksheet_association(resource, worksheet_name:, class_name:)
      @associations ||= {}
      if @associations.fetch(resource, nil)
        raise WorksheetAssociationAlreadyRegisteredError
      end
      @associations[resource] = {
        worksheet_name: worksheet_name,
        class_name: class_name
      }
    end

    def find_association_by_id(association_name, id)
      find_associations_by_ids(association_name, [id]).first
    end

    def find_associations_by_ids(association_name, ids)
      send(association_name).find_by_ids(ids)
    end

    def find_associations_by_attribute(association_name, attribute_name, value)
      send(association_name).find_by_attribute(attribute_name, value)
    end

    def select_from_association(association_name, &block)
      send(association_name).select(&block)
    end
  end
end