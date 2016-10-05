RSpec.describe SheetsDB::Session do
  let(:wrapped_session) { GoogleDriveSessionProxy.new }
  subject { SheetsDB::Session.new(wrapped_session) }

  context "clearing default Session" do
    around(:each) do |test|
      existing_default = described_class.default
      test.run
      described_class.default = existing_default
    end

    describe ".default=" do
      it "stores a default Session instance" do
        dummy_session = described_class.new(:drive_session)
        described_class.default = dummy_session
        expect(described_class.default).to eq(dummy_session)
      end

      it "raises an exception if attempting to set non-session default" do
        expect {
          described_class.default = "not a Session"
        }.to raise_error(described_class::IllegalDefaultError)
      end
    end

    describe ".default" do
      it "raises an exception if no default set" do
        described_class.instance_variable_set(:"@default", nil)
        expect {
          described_class.default
        }.to raise_error(described_class::NoDefaultSetError)
      end
    end
  end

  describe ".from_service_account_key" do
    it "returns a new instance authorized with a service account key" do
      allow(GoogleDrive::Session).to receive(:from_service_account_key).
        with(:json_path).
        and_return(:a_session)
      allow(described_class).to receive(:new).
        with(:a_session).
        and_return(:wrapped_session)
      expect(described_class.from_service_account_key(:json_path)).
        to eq(:wrapped_session)
    end
  end

  describe "#raw_file_by_id" do
    it "delegates to #file_by_id from wrapped session" do
      allow(wrapped_session).to receive(:file_by_id).with(:the_id).and_return(:raw_file)
      expect(subject.raw_file_by_id(:the_id)).to eq :raw_file
    end
  end
end