RSpec.describe SheetsDB::Collection do
  let(:test_class) { Class.new(described_class) }

  subject { test_class.new(GoogleDriveSessionProxy::DUMMY_FILES[:collection]) }

  describe ".find_by_id" do
    it "returns instance for given id" do
      expect(described_class.find_by_id(:collection)).to eq(subject)
    end

    it "raises error if id does not represent collection" do
      expect {
        described_class.find_by_id(:file)
      }.to raise_error(described_class::ResourceTypeMismatchError)
    end
  end

  describe ".has_many" do
    it "adds an association of subcollections" do
      test_association_class = Class.new(SheetsDB::Collection)
      allow(SheetsDB::Support).to receive(:constantize).with("Goose").and_return(test_association_class)
      test_class.has_many :teams, class_name: "Goose"
      allow(GoogleDriveSessionProxy::DUMMY_FILES[:collection]).
        to receive(:subcollections).
        and_return([:foo, :bar])
      expect(subject.teams).to eq([
        test_association_class.new(:foo),
        test_association_class.new(:bar)
      ])
    end

    it "adds an association of spreadsheets" do
      test_association_class = Class.new(SheetsDB::Spreadsheet)
      allow(SheetsDB::Support).to receive(:constantize).with("Goose").and_return(test_association_class)
      test_class.has_many :friends, class_name: "Goose", resource_type: :spreadsheets
      allow(GoogleDriveSessionProxy::DUMMY_FILES[:collection]).
        to receive(:spreadsheets).
        and_return([:foo, :bar])
      expect(subject.friends).to eq([
        test_association_class.new(:foo),
        test_association_class.new(:bar)
      ])
    end

    it "raises error if given unknown resource type" do
      test_association_class = Class.new
      expect {
        test_class.has_many :friends, class_name: "Whatever", resource_type: :foo
      }.to raise_error(ArgumentError, "resource_type must be :subcollections or :spreadsheets")
    end

    it "allows two associations of different base types" do
      expect {
        test_class.has_many :teams, class_name: "Foo"
        test_class.has_many :friends, class_name: "Bar", resource_type: :spreadsheets
      }.not_to raise_error
    end

    it "does not allow two associations of same base type" do
      expect {
        test_class.has_many :teams, class_name: "Foo"
        test_class.has_many :cadres, class_name: "Bar"
      }.to raise_error(described_class::CollectionTypeAlreadyRegisteredError)
    end
  end
end