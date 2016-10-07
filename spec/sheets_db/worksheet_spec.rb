RSpec.describe SheetsDB::Worksheet do
  let(:raw_worksheet) {
    instance_double(GoogleDrive::Worksheet, rows: [
      ["id", "first_name", "", "last_name"],
      ["1", "Anna", "", "Scoofles"],
      ["2", "Balaji", "n/a", "Rhutoni"]
    ])
  }
  let(:row_class) { SheetsDB::Worksheet::Row }
  subject { described_class.new(worksheet: raw_worksheet, type: row_class) }

  describe "#all" do
    it "returns instances of type for each row in worksheet" do
      expect(subject.all.map(&:id)).to eq([1, 2])
    end
  end

  describe "#find_by_id" do
    it "returns row with given id" do
      expect(subject.find_by_id(2).instance_variable_get(:@first_name)).to eq("Balaji")
    end
  end

  describe "#columns" do
    it "returns columns with names and positions" do
      expect(subject.columns).to eq([
        SheetsDB::Worksheet::Column.new(name: :id, column_position: 1),
        SheetsDB::Worksheet::Column.new(name: :first_name, column_position: 2),
        SheetsDB::Worksheet::Column.new(name: :last_name, column_position: 4)
      ])
    end
  end
end
