RSpec.describe SheetsDB::Collection do
  let(:test_class) { Class.new(described_class) }
  let(:raw_collection) { GoogleDriveSessionProxy::DUMMY_FILES[:collection] }

  subject { test_class.new(raw_collection) }

  it "is a SheetsDB::Resource" do
    expect(subject).to be_a(SheetsDB::Resource)
  end

  describe ".has_many" do
    it "adds an association of subcollections" do
      test_association_class = Class.new(SheetsDB::Collection)
      allow(SheetsDB::Support).to receive(:constantize).with("Goose").and_return(test_association_class)
      test_class.has_many :teams, class_name: "Goose"
      allow(raw_collection).
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
      allow(raw_collection).
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

  %i[
    spreadsheet
    subcollection
  ].each do |child_resource_type|
    method_name = :"google_drive_#{child_resource_type}_by_title"
    describe "##{method_name}" do
      it "calls find_child_google_drive_resource_by for given type" do
        allow(subject).to receive(:find_child_google_drive_resource_by).
          with(type: child_resource_type, title: :the_title, create: :maybe).
          and_return(:the_result)
        expect(
          subject.public_send(method_name, :the_title, create: :maybe)
        ).to eq(:the_result)
      end
    end
  end

  describe "#spreadsheets" do
    it "returns base Spreadsheet instance for each of collection's spreadsheet resources" do
      allow(raw_collection).to receive(:spreadsheets).and_return([:s1, :s2])
      allow(SheetsDB::Spreadsheet).to receive(:new).with(:s1).and_return(:sds1)
      allow(SheetsDB::Spreadsheet).to receive(:new).with(:s2).and_return(:sds2)
      expect(subject.spreadsheets).to eq([:sds1, :sds2])
    end
  end

  describe "#collections" do
    it "returns base Collection instance for each of collection's subcollection resources" do
      allow(raw_collection).to receive(:subcollections).and_return([:c1, :c2])
      allow(SheetsDB::Collection).to receive(:new).and_call_original
      allow(SheetsDB::Collection).to receive(:new).with(:c1).and_return(:sdc1)
      allow(SheetsDB::Collection).to receive(:new).with(:c2).and_return(:sdc2)
      expect(subject.collections).to eq([:sdc1, :sdc2])
    end
  end
end
