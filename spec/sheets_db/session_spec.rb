RSpec.describe SheetsDB::Session do
  context "clearing default Session" do
    after(:each) do |test|
      described_class.instance_variable_set(:@default, nil)
    end

    describe ".default=" do
      it "stores a default Session instance" do
        dummy_session = described_class.new(:drive_session)
        described_class.default = dummy_session
        expect(described_class.default).to eq(dummy_session)
      end

      it "raises an exception if attempting to set non-hive default" do
        expect {
          described_class.default = "not a Hive"
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

  describe "#from_service_account_key" do
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
end