RSpec.describe SheetsDB::Worksheet do
  let(:raw_worksheet) {
    instance_double(GoogleDrive::Worksheet,
      rows: [
        ["id", "first_name", "", "last_name"],
        ["1", "Anna", "", "Scoofles"],
        ["2", "Balaji", "n/a", "Rhutoni"],
        ["3", "Snoof", "", "McDoorney"]
      ],
      num_rows: 4
    )
  }
  let(:row_class) { SheetsDB::Worksheet::Row }
  subject { described_class.new(spreadsheet: :the_spreadsheet, google_drive_resource: raw_worksheet, type: row_class) }

  describe "#attribute_at_row_position" do
    it "returns the value for the given attribute at the given row index" do
      allow(raw_worksheet).to receive(:[]).with(2, 2).and_return("Anna")
      expect(subject.attribute_at_row_position(:first_name, row_position: 2)).to eq("Anna")
    end

    it "converts the given value according to type" do
      allow(raw_worksheet).to receive(:[]).with(2, 2).and_return("Anna")
      allow(subject).to receive(:convert_value).with("Anna", :the_type).and_return("Deanna")
      expect(subject.attribute_at_row_position(:first_name, row_position: 2, type: :the_type)).to eq("Deanna")
    end

    it "splits multiple return values" do
      allow(raw_worksheet).to receive(:[]).with(2, 2).and_return("Anna, Banana")
      allow(subject).to receive(:convert_value).with("Anna", :the_type).and_return("Deanna")
      allow(subject).to receive(:convert_value).with("Banana", :the_type).and_return("The Banana")
      expect(subject.attribute_at_row_position(:first_name, row_position: 2, type: :the_type, multiple: true)).to eq(["Deanna", "The Banana"])
    end
  end

  describe "#update_attributes_at_row_position" do
    it "updates the given attributes using the google drive resource" do
      expect(raw_worksheet).to receive(:[]=).with(2, 2, "Bonnie")
      expect(raw_worksheet).to receive(:[]=).with(2, 4, "McFragile")
      expect(raw_worksheet).to receive(:synchronize)
      subject.update_attributes_at_row_position({ first_name: "Bonnie", last_name: "McFragile" }, row_position: 2)
    end
  end

  describe "#all" do
    it "returns instances of type for each row in worksheet" do
      allow(row_class).to receive(:new).with(worksheet: subject, row_position: 2).
        and_return(:row_2)
      allow(row_class).to receive(:new).with(worksheet: subject, row_position: 3).
        and_return(:row_3)
      allow(row_class).to receive(:new).with(worksheet: subject, row_position: 4).
        and_return(:row_4)
      expect(subject.all).to eq([:row_2, :row_3, :row_4])
    end
  end

  describe "#find_by_id" do
    it "returns row with given id" do
      allow(subject).to receive(:find_by_ids).with([2]).and_return([:result])
      expect(subject.find_by_id(2)).to eq(:result)
    end

    it "returns nil if id not found" do
      allow(subject).to receive(:find_by_ids).with([2]).and_return([])
      expect(subject.find_by_id(2)).to be_nil
    end
  end

  describe "#find_by_ids" do
    it "returns rows with given ids" do
      row_class.attribute :id, type: Integer

      allow(raw_worksheet).to receive(:[]).with(2, 1).and_return("1")
      allow(raw_worksheet).to receive(:[]).with(3, 1).and_return("2")
      allow(raw_worksheet).to receive(:[]).with(4, 1).and_return("3")
      expect(subject.find_by_ids([2, 3]).map(&:row_position)).to eq([3, 4])
    end
  end

  describe "#columns" do
    it "returns columns with names and positions" do
      expect(subject.columns).to eq({
        id: SheetsDB::Worksheet::Column.new(name: :id, column_position: 1),
        first_name: SheetsDB::Worksheet::Column.new(name: :first_name, column_position: 2),
        last_name: SheetsDB::Worksheet::Column.new(name: :last_name, column_position: 4)
      })
    end
  end

  describe "#reload!" do
    it "reloads the google_drive_resource worksheet" do
      expect(raw_worksheet).to receive(:reload)
      subject.reload!
    end
  end

  describe "#convert_value" do
    it "returns nil if given a blank string" do
      expect(subject.convert_value("", :whatever)).to be_nil
    end

    it "returns given value if unrecognized type" do
      expect(subject.convert_value("something", :whatever)).to eq("something")
    end

    it "returns integer value if type is Integer" do
      expect(subject.convert_value("14", Integer)).to eq(14)
    end
  end
end
