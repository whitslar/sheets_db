RSpec.describe SheetsDB::Worksheet::Row do
  let(:row_class) { Class.new(described_class) }
  let(:worksheet) { SheetsDB::Worksheet.new(worksheet: :a_worksheet, type: row_class) }
  subject { row_class.new(worksheet: :a_worksheet, row_position: 3, foo: "1", bar: "2", things: "1,2, 3") }

  describe ".new" do
    it "assigns arbitrary attributes" do
      row_class.send(:attr_reader, :foo, :bar, :things)
      expect(subject.foo).to eq("1")
      expect(subject.bar).to eq("2")
      expect(subject.things).to eq("1,2, 3")
    end
  end

  describe ".column" do
    it "sets up accessor for integer type columns" do
      row_class.column :foo, type: Integer
      expect(subject.foo).to eq(1)
    end

    it "sets up accessor for default string columns" do
      row_class.column :foo
      expect(subject.foo).to eq("1")
    end

    it "sets up accessor for collection columns" do
      row_class.column :things, type: Integer, collection: true
      expect(subject.things).to eq([1, 2, 3])
    end
  end
end
