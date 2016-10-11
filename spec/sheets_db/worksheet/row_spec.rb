RSpec.describe SheetsDB::Worksheet::Row do
  let(:row_class) { Class.new(described_class) }
  let(:worksheet) { SheetsDB::Worksheet.new(spreadsheet: :a_spreadsheet, google_drive_resource: :a_worksheet, type: row_class) }
  subject { row_class.new(worksheet: worksheet, row_position: 3) }

  describe ".attribute" do
    context "with basic attribute" do
      before(:each) do
        row_class.attribute :foo
      end

      it "sets up reader for attribute, with String conversion" do
        allow(worksheet).to receive(:attribute_at_row_position).with(:foo, row_position: 3).and_return("1")
        allow(subject).to receive(:convert_value).with("1", String).and_return("the_number_1")
        expect(subject.foo).to eq("the_number_1")
      end
    end

    context "with type specification" do
      before(:each) do
        row_class.attribute :foo, type: :the_type
      end

      it "sets up reader for attribute, with type conversion" do
        allow(worksheet).to receive(:attribute_at_row_position).with(:foo, row_position: 3).and_return("1")
        allow(subject).to receive(:convert_value).with("1", :the_type).and_return("the_number_1")
        expect(subject.foo).to eq("the_number_1")
      end
    end

    context "with collection attribute" do
      before(:each) do
        row_class.attribute :things, type: :the_type, collection: true
      end

      it "sets up reader for attribute, with type conversion" do
        allow(worksheet).to receive(:attribute_at_row_position).with(:things, row_position: 3).and_return("1,2, 3")
        allow(subject).to receive(:convert_value).with("1", :the_type).and_return(1)
        allow(subject).to receive(:convert_value).with("2", :the_type).and_return(2)
        allow(subject).to receive(:convert_value).with("3", :the_type).and_return(3)
        expect(subject.things).to eq([1, 2, 3])
      end
    end

  end
end
