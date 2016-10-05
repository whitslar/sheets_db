RSpec.describe SheetsDB::Spreadsheet do
  let(:test_class) { Class.new(described_class) }

  subject { test_class.new(GoogleDriveSessionProxy::DUMMY_FILES[:spreadsheet]) }

  describe ".find_by_id" do
    it "returns instance for given id" do
      expect(described_class.find_by_id(:spreadsheet)).to eq(subject)
    end

    it "raises error if id does not represent spreadsheet" do
      expect {
        described_class.find_by_id(:file)
      }.to raise_error(described_class::ResourceTypeMismatchError)
    end
  end
end