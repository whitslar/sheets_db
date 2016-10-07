RSpec.describe SheetsDB::Worksheet::Row do
  let(:row_class) { Class.new(described_class) }
  let(:worksheet) { SheetsDB::Worksheet.new(worksheet: :a_worksheet, type: row_class) }
  subject { row_class.new(worksheet: :a_worksheet, row_position: 3, foo: 1, bar: 2) }

  describe ".new" do
    it "assigns arbitrary attributes" do
      row_class.send(:attr_reader, :foo, :bar)
      expect(subject.foo).to eq(1)
      expect(subject.bar).to eq(2)
    end
  end
end
