RSpec.describe SheetsDB::Collection do
  let(:test_class) { Class.new(described_class) }
  let(:raw_collection) { GoogleDrive::Collection.new(self, "collection") }

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

  describe "#find_spreadsheet" do
    it "returns result of #find_spreadsheet!" do
      allow(subject).to receive(:find_spreadsheet!).
        with(title: :the_title).
        and_return(:the_sheet)
      expect(subject.find_spreadsheet(title: :the_title)).to eq(:the_sheet)
    end

    it "returns nil if #find_spreadsheet! raises ChildResourceNotFoundError" do
      allow(subject).to receive(:find_spreadsheet!).
        with(title: :the_title).
        and_raise(described_class::ChildResourceNotFoundError)
      expect(subject.find_spreadsheet(title: :the_title)).to be_nil
    end
  end

  describe "#find_spreadsheet!" do
    it "returns result of #find_and_wrap_spreadsheet! with create false" do
      allow(subject).to receive(:find_and_wrap_spreadsheet!).
        with(title: :the_title, create: false).
        and_return(:the_sheet)
      expect(subject.find_spreadsheet!(title: :the_title)).to eq(:the_sheet)
    end

    it "bubbles exception if #find_and_wrap_spreadsheet! raises ChildResourceNotFoundError" do
      allow(subject).to receive(:find_and_wrap_spreadsheet!).
        with(title: :the_title, create: false).
        and_raise(described_class::ChildResourceNotFoundError)
      expect {
        subject.find_spreadsheet!(title: :the_title)
      }.to raise_error(described_class::ChildResourceNotFoundError)
    end
  end

  describe "#find_or_create_spreadsheet!" do
    it "returns result of #find_and_wrap_spreadsheet! with create true" do
      allow(subject).to receive(:find_and_wrap_spreadsheet!).
        with(title: :the_title, create: true).
        and_return(:the_sheet)
      expect(subject.find_or_create_spreadsheet!(title: :the_title)).to eq(:the_sheet)
    end
  end

  describe "#find_and_wrap_spreadsheet!" do
    let(:create) { false }

    before do
      allow(subject).to receive(:google_drive_spreadsheet_by_title).
        with(:the_title, create: create).
        and_return(:raw_spreadsheet)
      allow(SheetsDB::Spreadsheet).to receive(:new).
        with(:raw_spreadsheet).
        and_return(:the_set_up_sheet)
    end

    context "when not creating" do
      it "gets spreadsheet by title and sets it up" do
        expect(
          subject.find_and_wrap_spreadsheet!(title: :the_title, create: create)
        ).to eq(:the_set_up_sheet)
      end

      context "when no worksheet found" do
        it "raises ChildResourceNotFoundError" do
          allow(subject).to receive(:google_drive_spreadsheet_by_title).
            with(:the_title, create: create).
            and_raise(SheetsDB::Resource::ChildResourceNotFoundError)

          expect {
            subject.find_and_wrap_spreadsheet!(title: :the_title, create: create)
          }.to raise_error(described_class::SpreadsheetNotFoundError)
        end
      end
    end

    context "when not creating" do
      let(:create) { true }

      it "gets spreadsheet by title, creating if necessary, and sets it up" do
        expect(
          subject.find_and_wrap_spreadsheet!(title: :the_title, create: create)
        ).to eq(:the_set_up_sheet)
      end
    end

    it "defaults to create = false" do
      expect(
        subject.find_and_wrap_spreadsheet!(title: :the_title)
      ).to eq(:the_set_up_sheet)
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
