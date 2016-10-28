RSpec.describe SheetsDB::Resource do
  let(:raw_file) { GoogleDriveSessionProxy::DUMMY_FILES[:file]}
  let(:test_class) { Class.new(described_class) }

  subject { test_class.new(raw_file) }


  # let(:raw_file) { GoogleDriveSessionProxy::DUMMY_FILES[:file] }
  # subject { described_class.new(raw_file) }

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
end