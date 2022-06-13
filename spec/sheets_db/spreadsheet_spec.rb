RSpec.describe SheetsDB::Spreadsheet do
  let(:test_class) { Class.new(described_class) }
  let(:raw_file) { GoogleDriveSessionProxy::DUMMY_FILES[:spreadsheet] }

  subject { test_class.new(raw_file) }

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
      test_class.has_many :widgets, worksheet_name: "Widgets", class_name: "Goose"
      allow(subject).to receive(:worksheet_association).
        with(:widgets, worksheet_name: "Widgets", class_name: "Goose").
        and_return(:the_worksheet_association)
      expect(subject.widgets).to eq(:the_worksheet_association)
    end

    it "does not allow two associations of same name" do
      expect {
        test_class.has_many :widgets, worksheet_name: "Widgets", class_name: :collection_class
        test_class.has_many :widgets, worksheet_name: "Widgets2", class_name: :collection_class
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

  describe "#select_from_association" do
    it "is a proxy for the select method on an association" do
      allow(subject).to receive(:widgets).and_return([1, 2, 3, 4])
      expect(subject.select_from_association(:widgets) { |i| i < 3 }).to eq([1, 2])
    end
  end

  describe "#find_associations_by_attribute" do
    it "delegates find_by_attribute to the given resource" do
      widget_proxy = instance_double(SheetsDB::Worksheet)
      allow(widget_proxy).to receive(:find_by_attribute).with(:foo, 2).and_return([:w2, :w3])
      allow(subject).to receive(:widgets).and_return(widget_proxy)
      expect(subject.find_associations_by_attribute(:widgets, :foo, 2)).to eq([:w2, :w3])
    end
  end

  describe "#worksheet_association" do
    before do
      allow(SheetsDB::Support).to receive(:constantize).with("Goose").and_return(:a_type)
      allow(subject).to receive(:find_or_create_worksheet!).
        with(title: "Widgets", type: :a_type).
        once.
        and_return(:the_worksheet_association)
    end

    it "returns a memoized worksheet parser for the given resource and args" do
      subject.worksheet_association(:widgets, worksheet_name: "Widgets", class_name: "Goose")
      expect(
        subject.worksheet_association(:widgets, worksheet_name: "Widgets", class_name: "Goose")
      ).to eq(:the_worksheet_association)
    end
  end

  describe "#worksheets" do
    it "returns base Worksheet instance for each of spreadsheet's worksheet resources" do
      allow(raw_file).to receive(:worksheets).and_return([:w1, :w2])
      allow(subject).to receive(:set_up_worksheet!).with(google_drive_resource: :w1).and_return(:sdw1)
      allow(subject).to receive(:set_up_worksheet!).with(google_drive_resource: :w2).and_return(:sdw2)
      expect(subject.worksheets).to eq([:sdw1, :sdw2])
    end
  end

  describe "#set_up_worksheet!" do
    let(:worksheet) { instance_double(SheetsDB::Worksheet) }

    before do
      allow(worksheet).to receive(:set_up!).and_return(:the_set_up_sheet)
    end

    it "instantiates and sets up worksheet for given resource and type" do
      allow(SheetsDB::Worksheet).to receive(:new).
        with(google_drive_resource: :raw_worksheet, spreadsheet: subject, type: :the_type).
        and_return(worksheet)
      expect(
        subject.set_up_worksheet!(google_drive_resource: :raw_worksheet, type: :the_type)
      ).to eq(:the_set_up_sheet)
    end

    it "defaults to nil type" do
      allow(SheetsDB::Worksheet).to receive(:new).
        with(google_drive_resource: :raw_worksheet, spreadsheet: subject, type: nil).
        and_return(worksheet)
      expect(
        subject.set_up_worksheet!(google_drive_resource: :raw_worksheet)
      ).to eq(:the_set_up_sheet)
    end
  end

  describe "#find_or_create_worksheet!" do
    before do
      allow(subject).to receive(:google_drive_worksheet_by_title).
        with(:the_title, create: true).
        and_return(:raw_worksheet)
    end

    it "finds or creates google drive worksheet and sets it up" do
      allow(subject).to receive(:set_up_worksheet!).
        with(google_drive_resource: :raw_worksheet, type: :the_type).
        and_return(:the_set_up_sheet)
      expect(
        subject.find_or_create_worksheet!(title: :the_title, type: :the_type)
      ).to eq(:the_set_up_sheet)
    end

    it "defaults to nil type" do
      allow(subject).to receive(:set_up_worksheet!).
        with(google_drive_resource: :raw_worksheet, type: nil).
        and_return(:the_set_up_sheet)
      expect(
        subject.find_or_create_worksheet!(title: :the_title)
      ).to eq(:the_set_up_sheet)
    end
  end

  describe "#google_drive_worksheet_by_title" do
    it "calls find_child_google_drive_resource_by for worksheet type" do
      allow(subject).to receive(:find_child_google_drive_resource_by).
        with(type: :worksheet, title: :the_title, create: :maybe).
        and_return(:the_result)
      expect(
        subject.google_drive_worksheet_by_title(:the_title, create: :maybe)
      ).to eq(:the_result)
    end
  end
end
