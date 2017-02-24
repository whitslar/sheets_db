RSpec.describe SheetsDB::Worksheet::Column do
  subject { described_class.new(name: "hats", column_position: 4) }

  describe "#==" do
    it "returns true if name and position are the same" do
      expect(subject).to eq(
        described_class.new(name: "hats", column_position: 4)
      )
    end

    it "returns false if other is not the same class" do
      expect(subject).not_to eq(
        OpenStruct.new(name: "hats", column_position: 4)
      )
    end

    it "returns false if name is different" do
      expect(subject).not_to eq(
        described_class.new(name: "gorph", column_position: 4)
      )
    end

    it "returns false if position is different" do
      expect(subject).not_to eq(
        described_class.new(name: "hats", column_position: 5)
      )
    end
  end
end