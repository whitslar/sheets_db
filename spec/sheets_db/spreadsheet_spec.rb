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

  describe ".has_many" do
    it "adds an association to a worksheet parser" do
      test_class.has_many :widgets, sheet_name: "Widgets", type: :collection_class
      allow(GoogleDriveSessionProxy::DUMMY_FILES[:spreadsheet]).
        to receive(:worksheet_by_title).
        with("Widgets").
        and_return(:the_worksheet)
      expect(subject.widgets).to eq(
        SheetsDB::Worksheet.new(spreadsheet: subject, google_drive_resource: :the_worksheet, type: :collection_class)
      )
    end

    it "does not allow two associations of same name" do
      expect {
        test_class.has_many :widgets, sheet_name: "Widgets", type: :collection_class
        test_class.has_many :widgets, sheet_name: "Widgets2", type: :collection_class
      }.to raise_error(described_class::WorksheetAssociationAlreadyRegisteredError)
    end
  end

  describe "#find_association_by_id" do
    it "singular proxy for find_associations_by_ids" do
      allow(subject).to receive(:find_associations_by_ids).
        with(:widgets, [3]).and_return([:w3])
      expect(subject.find_association_by_id(:widgets, 3)).to eq(:w3)
    end
  end

  describe "#find_associations_by_ids" do
    it "delegates find_by_ids to the given resource" do
      widget_proxy = instance_double(SheetsDB::Worksheet)
      allow(widget_proxy).to receive(:find_by_ids).with([2, 3]).and_return([:w2, :w3])
      allow(subject).to receive(:widgets).and_return(widget_proxy)
      expect(subject.find_associations_by_ids(:widgets, [2, 3])).to eq([:w2, :w3])
    end
  end
end