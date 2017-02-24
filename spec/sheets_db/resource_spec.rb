RSpec.describe SheetsDB::Resource do
  let(:raw_file) { GoogleDriveSessionProxy::DUMMY_FILES[:file]}
  let(:test_class) { Class.new(described_class) }

  subject { test_class.new(raw_file) }

  describe ".find_by_id" do
    it "returns instance for given id" do
      expect(test_class.find_by_id(:file)).to eq(subject)
    end
  end

  describe "#id" do
    it "delegates to raw resource" do
      allow(raw_file).to receive(:id).and_return(:foo)
      expect(subject.id).to eq(:foo)
    end
  end

  describe "#name" do
    it "delegates to raw resource" do
      allow(raw_file).to receive(:name).and_return(:foo)
      expect(subject.name).to eq(:foo)
    end
  end

  describe "#created_at" do
    it "delegates to raw resource #created_time" do
      allow(raw_file).to receive(:created_time).and_return(:foo)
      expect(subject.created_at).to eq(:foo)
    end
  end

  describe "#updated_at" do
    it "delegates to raw resource #modified_time" do
      allow(raw_file).to receive(:modified_time).and_return(:foo)
      expect(subject.updated_at).to eq(:foo)
    end
  end

  describe ".belongs_to_many" do
    it "adds an association of parents" do
      test_association_class = Class.new(SheetsDB::Collection)
      allow(SheetsDB::Support).to receive(:constantize).with("Goose").and_return(test_association_class)
      test_class.belongs_to_many :worlds, class_name: "Goose"
      allow(raw_file).
        to receive(:parents).
        and_return([:foo, :bar])
      allow(test_association_class).to receive(:find_by_id).with(:foo).and_return(:foo_parent)
      allow(test_association_class).to receive(:find_by_id).with(:bar).and_return(:bar_parent)
      expect(subject.worlds).to eq([:foo_parent, :bar_parent])
    end

    it "does not allow two parent associations" do
      expect {
        test_class.belongs_to_many :teams, class_name: "Foo"
        test_class.belongs_to_many :cadres, class_name: "Bar"
      }.to raise_error(described_class::CollectionTypeAlreadyRegisteredError)
    end
  end

  describe "#base_attributes" do
    it "returns hash of common resource attributes" do
      allow(subject).to receive(:id).and_return(12)
      allow(subject).to receive(:name).and_return("Riverboat")
      allow(subject).to receive(:created_at).and_return(:a_while_ago)
      allow(subject).to receive(:updated_at).and_return(:recently)
      expect(subject.base_attributes).to eq({
        id: 12,
        name: "Riverboat",
        created_at: :a_while_ago,
        updated_at: :recently
      })
    end
  end

  describe "#==" do
    it "returns true if google drive resource is the same" do
      expect(subject).to eq(test_class.new(raw_file))
    end

    it "returns false if other is not a resource" do
      expect(subject).not_to eq(SheetsDB::Worksheet.new(
        spreadsheet: :foo, google_drive_resource: raw_file, type: :bar
      ))
    end

    it "returns false if google drive resource is different" do
      expect(subject).not_to eq(test_class.new(
        GoogleDrive::File.new(self, "file")
      ))
    end
  end

  describe "#eql?" do
    it "aliases to ==" do
      expect(subject.method(:eql?)).to eq(subject.method(:==))
    end
  end

  describe "#hash" do
    it "returns hash of class and google drive resource" do
      expect(subject.hash).to eq(
        [test_class, raw_file].hash
      )
    end
  end
end