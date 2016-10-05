require "google_drive"

class GoogleDriveSessionProxy
  DUMMY_FILES = {
    collection: GoogleDrive::Collection.new(self, "collection"),
    file: GoogleDrive::File.new(self, "file"),
    spreadsheet: GoogleDrive::Spreadsheet.new(self, "spreadsheet")
  }

  def file_by_id(id)
    DUMMY_FILES.fetch(id)
  end
end