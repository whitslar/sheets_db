RSpec.describe SheetsDB::Resource do
  subject { described_class.new(GoogleDriveSessionProxy::DUMMY_FILES[:file]) }

  describe ".find_by_id" do
    it "returns instance for given id" do
      expect(described_class.find_by_id(:file)).to eq(subject)
    end
  end
end