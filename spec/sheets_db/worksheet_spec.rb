RSpec.describe SheetsDB::Worksheet do
  let(:raw_worksheet) {
    instance_double(GoogleDrive::Worksheet,
      rows: [
        ["id", "first_name", "", "last_name", "colors", "Food (Titleized)"],
        ["1", "Anna", "", "Scoofles", "", "pickles"],
        ["2", "Balaji", "n/a", "Rhutoni", "", "noodles"],
        ["3", "Snoof", "", "McDoorney", "", ""],
        ["4", "Anna", "", "Karenina", "", ""]
      ],
      num_rows: 5
    )
  }
  let(:row_class) { SheetsDB::Worksheet::Row }
  subject { described_class.new(spreadsheet: :the_spreadsheet, google_drive_resource: raw_worksheet, type: row_class) }

  describe "#attribute_at_row_position" do
    it "returns the value for the given attribute at the given row index" do
      allow(raw_worksheet).to receive(:[]).with(2, 2).and_return("Anna")
      allow(row_class).to receive(:attribute_definitions).and_return({ first_name: { transform: Proc.new { |val| val.upcase } } })
      expect(subject.attribute_at_row_position(:first_name, 2)).to eq("ANNA")
    end

    it "utilizes custom column name" do
      allow(raw_worksheet).to receive(:[]).with(2, 6).and_return("cabbage")
      allow(row_class).to receive(:attribute_definitions).and_return({ the_food: { column_name: "Food (Titleized)" } })
      expect(subject.attribute_at_row_position(:the_food, 2)).to eq("cabbage")
    end

    it "converts the given value according to type" do
      allow(raw_worksheet).to receive(:[]).with(2, 2).and_return("Anna")
      allow(row_class).to receive(:attribute_definitions).and_return({ first_name: { type: :the_type } })
      allow(subject).to receive(:convert_value).with("Anna", { type: :the_type }).and_return("Deanna")
      expect(subject.attribute_at_row_position(:first_name, 2)).to eq("Deanna")
    end

    it "converts the given value according to type" do
      allow(raw_worksheet).to receive(:[]).with(2, 2).and_return("Anna")
      allow(row_class).to receive(:attribute_definitions).and_return({ first_name: { type: :the_type } })
      allow(subject).to receive(:convert_value).with("Anna", { type: :the_type }).and_return("Deanna")
      expect(subject.attribute_at_row_position(:first_name, 2)).to eq("Deanna")
    end

    it "splits multiple return values" do
      allow(raw_worksheet).to receive(:[]).with(2, 2).and_return("Anna, Banana")
      allow(row_class).to receive(:attribute_definitions).and_return({ first_name: { type: :the_type, multiple: true } })
      allow(subject).to receive(:convert_value).with("Anna", { type: :the_type, multiple: true }).and_return("Deanna")
      allow(subject).to receive(:convert_value).with("Banana", { type: :the_type, multiple: true }).and_return("The Banana")
      expect(subject.attribute_at_row_position(:first_name, 2)).to eq(["Deanna", "The Banana"])
    end

    it "reads input values directly if type is DateTime" do
      allow(raw_worksheet).to receive(:input_value).with(2, 2).and_return("April 15")
      allow(row_class).to receive(:attribute_definitions).and_return({ first_name: { type: DateTime } })
      allow(subject).to receive(:convert_value).with("April 15", { type: DateTime }).and_return("4/15")
      expect(subject.attribute_at_row_position(:first_name, 2)).to eq("4/15")
    end
  end

  describe "#update_attributes_at_row_position" do
    it "updates the given attributes using the google drive resource" do
      allow(row_class).to receive(:attribute_definitions).and_return({
        first_name: {},
        last_name: {},
        colors: { multiple: true },
        the_food: { column_name: "Food (Titleized)" }
      })
      expect(raw_worksheet).to receive(:[]=).with(2, 2, "Bonnie")
      expect(raw_worksheet).to receive(:[]=).with(2, 4, "McFragile")
      expect(raw_worksheet).to receive(:[]=).with(2, 5, "green,white")
      expect(raw_worksheet).to receive(:[]=).with(2, 6, "tasties")
      expect(raw_worksheet).to receive(:synchronize)
      subject.update_attributes_at_row_position({ first_name: "Bonnie", last_name: "McFragile", colors: ["green", "white"], the_food: "tasties" }, row_position: 2)
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
      allow(row_class).to receive(:new).with(worksheet: subject, row_position: 5).
        and_return(:row_5)
      expect(subject.all).to eq([:row_2, :row_3, :row_4, :row_5])
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

  describe "#find_by_attribute" do
    it "returns rows with matching attribute value" do
      row_class.attribute :first_name

      allow(raw_worksheet).to receive(:[]).with(2, 2).and_return("Anna")
      allow(raw_worksheet).to receive(:[]).with(3, 2).and_return("Frank")
      allow(raw_worksheet).to receive(:[]).with(4, 2).and_return("Parker")
      allow(raw_worksheet).to receive(:[]).with(5, 2).and_return("Anna")
      expect(subject.find_by_attribute(:first_name, "Anna").map(&:row_position)).to eq([2, 5])
    end
  end

  describe "#columns" do
    it "returns columns with names and positions" do
      expect(subject.columns).to eq({
        "id" => SheetsDB::Worksheet::Column.new(name: "id", column_position: 1),
        "first_name" => SheetsDB::Worksheet::Column.new(name: "first_name", column_position: 2),
        "last_name" => SheetsDB::Worksheet::Column.new(name: "last_name", column_position: 4),
        "colors" => SheetsDB::Worksheet::Column.new(name: "colors", column_position: 5),
        "Food (Titleized)" => SheetsDB::Worksheet::Column.new(name: "Food (Titleized)", column_position: 6)
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
      expect(subject.convert_value("", { type: :whatever })).to be_nil
    end

    it "returns given value if unrecognized type" do
      expect(subject.convert_value("something", { type: :whatever })).to eq("something")
    end

    it "returns integer value if type is Integer" do
      expect(subject.convert_value("14", { type: Integer })).to eq(14)
    end

    it "returns DateTime value if type is DateTime" do
      expect(subject.convert_value("4/15/2016 10:15:30", { type: DateTime })).to eq(
        DateTime.parse("2016-04-15 10:15:30")
      )
    end

    context "when type is Boolean" do
      it "returns true for TRUE value" do
        expect(subject.convert_value("TRUE", { type: :Boolean })).to eq(true)
        expect(subject.convert_value("True", { type: :Boolean })).to eq(true)
      end

      it "returns false for FALSE value" do
        expect(subject.convert_value("FALSE", { type: :Boolean })).to eq(false)
        expect(subject.convert_value("false", { type: :Boolean })).to eq(false)
      end

      it "returns nil for unknown value" do
        expect(subject.convert_value("goats", { type: :Boolean })).to eq(nil)
      end
    end
  end
end
