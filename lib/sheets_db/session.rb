require "google_drive"

module SheetsDB
  class Session
    class IllegalDefaultError < StandardError; end
    class NoDefaultSetError < StandardError; end
    class InvalidGoogleDriveUrlError < ArgumentError; end

    def self.default=(default)
      unless default.is_a?(self)
        raise IllegalDefaultError.new("Default must be a SheetsDB::Session")
      end
      @default = default
    end

    def self.default
      unless @default
        raise NoDefaultSetError.new("No default Session defined yet")
      end
      @default
    end

    def self.from_service_account_key(*args)
      new(GoogleDrive::Session.from_service_account_key(*args))
    end

    def initialize(google_drive_session)
      @google_drive_session = google_drive_session
    end

    def raw_file_by_id(id)
      @google_drive_session.file_by_id(id)
    end

    def raw_file_by_url(url)
      @google_drive_session.file_by_url(url)
    rescue GoogleDrive::Error => e
      (raise InvalidGoogleDriveUrlError, url) if e.message.match(/not a known Google Drive URL/)
      raise
    end
  end
end
