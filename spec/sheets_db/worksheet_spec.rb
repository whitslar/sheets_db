RSpec.describe SheetsDB::Worksheet do
  let(:raw_worksheet) { instance_double(GoogleDrive::Worksheet) }
  let(:row_class) { Class.new }
  subject { described_class.new(worksheet: raw_worksheet, type: row_class) }

  describe "#all" do
    it "returns instances of type for each row in worksheet" do
      allow(raw_worksheet).to receive(:rows).and_return([
        ["id", "first_name", "", "last_name"],
        ["1", "Anna", "", "Scoofles"],
        ["2", "Balaji", "n/a", "Rhutoni"]
      ])
      allow(row_class).to receive(:new).
        with(worksheet: subject, id: "1", first_name: "Anna", last_name: "Scoofles").
        and_return(:anna)
      allow(row_class).to receive(:new).
        with(worksheet: subject, id: "2", first_name: "Balaji", last_name: "Rhutoni").
        and_return(:balaji)
      expect(subject.all).to eq([:anna, :balaji])
    end
  end
end
