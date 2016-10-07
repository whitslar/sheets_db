RSpec.describe SheetsDB::Worksheet do
  let(:raw_worksheet) {
    instance_double(GoogleDrive::Worksheet, rows: [
      ["id", "first_name", "", "last_name"],
      ["1", "Anna", "", "Scoofles"],
      ["2", "Balaji", "n/a", "Rhutoni"]
    ])
  }
  let(:row_class) { Class.new }
  subject { described_class.new(worksheet: raw_worksheet, type: row_class) }

  describe "#all" do
    it "returns instances of type for each row in worksheet" do
      allow(row_class).to receive(:new).
        with(worksheet: subject, id: "1", first_name: "Anna", last_name: "Scoofles").
        and_return(:anna)
      allow(row_class).to receive(:new).
        with(worksheet: subject, id: "2", first_name: "Balaji", last_name: "Rhutoni").
        and_return(:balaji)
      expect(subject.all).to eq([:anna, :balaji])
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
