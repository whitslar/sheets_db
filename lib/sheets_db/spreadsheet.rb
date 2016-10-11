module SheetsDB
  class Spreadsheet < Resource
    class WorksheetAssociationAlreadyRegisteredError < StandardError; end

    set_resource_type GoogleDrive::Spreadsheet

    def self.has_many(resource, sheet_name:, type:)
      register_association(resource, sheet_name: sheet_name, type: type)
      define_method(resource) do
        Worksheet.new(
          spreadsheet: self,
          google_drive_resource: google_drive_resource.worksheet_by_title(sheet_name),
          type: type
        )
      end
    end

    def self.register_association(resource, sheet_name:, type:)
      @associations ||= {}
      if @associations.fetch(resource, nil)
        raise WorksheetAssociationAlreadyRegisteredError
      end
      @associations[resource] = [sheet_name, type]
    end
  end
end