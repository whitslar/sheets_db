RSpec.describe SheetsDB::Resource do
  let(:raw_file) { GoogleDriveSessionProxy::DUMMY_FILES[:file] }
  subject { described_class.new(raw_file) }

  describe ".find_by_id" do
    it "returns instance for given id" do
      expect(described_class.find_by_id(:file)).to eq(subject)
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
end