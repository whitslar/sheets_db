module SheetsDB
  class Spreadsheet < Resource
    class WorksheetAssociationAlreadyRegisteredError < StandardError; end
    class WorksheetNotFoundError < StandardError; end

    set_resource_type GoogleDrive::Spreadsheet

    class << self
      def has_many(resource, worksheet_name:, class_name:)
        register_worksheet_association(resource, worksheet_name: worksheet_name, class_name: class_name)
        create_worksheet_association(resource, worksheet_name: worksheet_name, class_name: class_name)
      end

      def register_worksheet_association(resource, worksheet_name:, class_name:)
        @associations ||= {}
        if @associations.fetch(resource, nil)
          raise WorksheetAssociationAlreadyRegisteredError
        end
        @associations[resource] = {
          worksheet_name: worksheet_name,
          class_name: class_name
        }
      end

      def create_worksheet_association(resource, **kwargs)
        define_method(resource) do
          worksheet_association(resource, **kwargs)
        end
      end
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

    def worksheet_association(association_name, worksheet_name:, class_name:)
      @associated_resources ||= {}
      @associated_resources[association_name] ||=
        find_or_create_worksheet!(title: worksheet_name, type: Support.constantize(class_name))
    end

    def worksheets
      @anonymous_resources ||= {}
      @anonymous_resources[:worksheets] ||= google_drive_resource.worksheets.map { |raw|
        set_up_worksheet!(google_drive_resource: raw)
      }
    end

    def set_up_worksheet!(google_drive_resource:, type: nil)
      Worksheet.new(
        google_drive_resource: google_drive_resource,
        spreadsheet: self,
        type: type
      ).set_up!
    end

    def find_or_create_worksheet!(title:, type: nil)
      resource = google_drive_worksheet_by_title(title, create: true)
      set_up_worksheet!(google_drive_resource: resource, type: type)
    end

    def google_drive_worksheet_by_title(title, **kwargs)
      find_child_google_drive_resource_by(type: :worksheet, title: title, **kwargs)
    end
  end
end
