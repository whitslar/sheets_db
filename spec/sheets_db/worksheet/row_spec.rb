RSpec.describe SheetsDB::Worksheet::Row do
  let(:row_class) { Class.new(described_class) }
  let(:spreadsheet) { SheetsDB::Spreadsheet.new(google_drive_resource: :a_spreadsheet) }
  let(:worksheet) { SheetsDB::Worksheet.new(spreadsheet: spreadsheet, google_drive_resource: :a_worksheet, type: row_class) }
  subject { row_class.new(worksheet: worksheet, row_position: 3) }

  before(:each) do
    row_class.instance_variable_set(:@attribute_definitions, nil)
    row_class.instance_variable_set(:@association_definitions, nil)
  end

  describe ".attribute" do
    context "with basic attribute" do
      before(:each) do
        allow(worksheet).to receive(:attribute_at_row_position).with(:foo, row_position: 3, type: String, multiple: false).once.and_return("the_number_1")
        row_class.attribute :foo
      end

      it "sets up memoized reader for attribute, with String conversion" do
        subject.foo
        expect(subject.foo).to eq("the_number_1")
      end

      it "returns staged change if exists" do
        subject.loaded_attributes[:foo] = { changed: "a_new_number" }
        expect(subject.foo).to eq("a_new_number")
      end

      it "sets up writer for attribute that stages change but doesn't persist it" do
        subject.foo = "a_new_number"
        expect(subject.loaded_attributes[:foo][:changed]).to eq("a_new_number")
        allow(worksheet).to receive(:reload!)
        subject.reload!
        expect(subject.foo).to eq("the_number_1")
      end

      it "raises an error if attribute already registered" do
        expect {
          row_class.attribute :foo
        }.to raise_error(described_class::AttributeAlreadyRegisteredError)
      end
    end

    context "with type specification" do
      before(:each) do
        allow(worksheet).to receive(:attribute_at_row_position).with(:foo, row_position: 3, type: :the_type, multiple: false).once.and_return("the_number_1")
        row_class.attribute :foo, type: :the_type
      end

      it "sets up reader for attribute, with type conversion" do
        allow(subject).to receive(:convert_value).with("1", :the_type).and_return("the_number_1")
        expect(subject.foo).to eq("the_number_1")
      end
    end

    context "with collection attribute" do
      before(:each) do
        allow(worksheet).to receive(:attribute_at_row_position).with(:things, row_position: 3, type: :the_type, multiple: true).and_return([1, 2, 3])
        row_class.attribute :things, type: :the_type, multiple: true
      end

      it "sets up reader for attribute, with type conversion" do
        expect(subject.things).to eq([1, 2, 3])
      end
    end
  end

  describe ".has_many" do
    before(:each) do
      row_class.has_many :widgets, from_collection: :widgets, key: :widget_ids
    end

    it "sets up reader for association, delegating lookup to spreadsheet" do
      allow(spreadsheet).to receive(:find_associations_by_ids).with(:widgets, [1, 2]).and_return([:w1, :w2])
      allow(subject).to receive(:widget_ids).and_return([1, 2])
      expect(subject.widgets).to eq([:w1, :w2])
    end

    it "sets up writer that sets key and memoized association" do
      w1, w2 = double(id: 1), double(id: 2)
      expect(subject).to receive(:widget_ids=).with([1, 2])
      subject.widgets = [w1, w2]
      expect(subject.widgets).to eq([w1, w2])
    end

    it "raises an error if attribute already registered" do
      expect {
        row_class.has_many :widgets, from_collection: :widgets, key: :widget_ids
      }.to raise_error(described_class::AttributeAlreadyRegisteredError)
    end
  end

  describe ".has_one" do
    before(:each) do
      row_class.has_one :widget, from_collection: :widgets, key: :widget_id
    end

    it "sets up reader for association, delegating lookup to spreadsheet" do
      allow(spreadsheet).to receive(:find_associations_by_ids).with(:widgets, [18]).and_return([:the_widget])
      allow(subject).to receive(:widget_id).and_return(18)
      expect(subject.widget).to eq(:the_widget)
    end

    it "sets up writer that sets key and memoized association" do
      the_widget = double(id: 14)
      expect(subject).to receive(:widget_id=).with(14)
      subject.widget = the_widget
      expect(subject.widget).to eq(the_widget)
    end

    it "raises an error if attribute already registered" do
      expect {
        row_class.has_one :widget, from_collection: :widgets, key: :widget_id
      }.to raise_error(described_class::AttributeAlreadyRegisteredError)
    end
  end

  describe ".belongs_to_many" do
    before(:each) do
      row_class.attribute :id, type: Integer
      row_class.belongs_to_many :widgets, from_collection: :widgets, foreign_key: :this_id
    end

    it "sets up reader for association, delegating lookup to spreadsheet" do
      allow(spreadsheet).to receive(:find_associations_by_attribute).with(:widgets, :this_id, 18).and_return([:w1, :w2])
      allow(subject).to receive(:id).and_return(18)
      expect(subject.widgets).to eq([:w1, :w2])
    end

    it "sets up writer that sets foreign key and memoized association" do
      allow(spreadsheet).to receive(:widgets).and_return(double(attribute_definitions: { this_id: { multiple: false }}))
      subject.id = 12
      w1, w2 = double(this_id: 13), double(this_id: 14)
      expect(w1).to receive(:this_id=).with(12)
      expect(w2).to receive(:this_id=).with(12)
      subject.widgets = [w1, w2]
      expect(subject.widgets).to eq([w1, w2])
    end

    it "adds to foreign key if remote attribute is multiple" do
      allow(spreadsheet).to receive(:widgets).and_return(double(attribute_definitions: { this_id: { multiple: true }}))
      subject.id = 12
      w1, w2 = double(this_id: [13]), double(this_id: [14, 15])
      expect(w1).to receive(:this_id=).with([13, 12])
      expect(w2).to receive(:this_id=).with([14, 15, 12])
      subject.widgets = [w1, w2]
      expect(subject.widgets).to eq([w1, w2])
    end

    it "raises an error if attribute already registered" do
      expect {
        row_class.belongs_to_many :widgets, from_collection: :widgets, foreign_key: :this_id
      }.to raise_error(described_class::AttributeAlreadyRegisteredError)
    end
  end

  describe ".belongs_to_one" do
    before(:each) do
      row_class.attribute :id, type: Integer
      row_class.belongs_to_one :widget, from_collection: :widgets, foreign_key: :this_id
    end

    it "sets up reader for association, delegating lookup to spreadsheet" do
      allow(spreadsheet).to receive(:find_associations_by_attribute).with(:widgets, :this_id, 18).and_return([:the_widget])
      allow(subject).to receive(:id).and_return(18)
      expect(subject.widget).to eq(:the_widget)
    end

    it "sets up writer that sets foreign key and memoized association" do
      allow(spreadsheet).to receive(:widgets).and_return(double(attribute_definitions: { this_id: { multiple: false }}))
      subject.id = 12
      the_widget = double(this_id: 14)
      expect(the_widget).to receive(:this_id=).with(12)
      subject.widget = the_widget
      expect(subject.widget).to eq(the_widget)
    end

    it "adds to foreign key if remote attribute is multiple" do
      allow(spreadsheet).to receive(:widgets).and_return(double(attribute_definitions: { this_id: { multiple: true }}))
      subject.id = 12
      the_widget = double(this_id: [14, 15])
      expect(the_widget).to receive(:this_id=).with([14, 15, 12])
      subject.widget = the_widget
      expect(subject.widget).to eq(the_widget)
    end

    it "raises an error if attribute already registered" do
      expect {
        row_class.belongs_to_one :widget, from_collection: :widgets, foreign_key: :widget_id
      }.to raise_error(described_class::AttributeAlreadyRegisteredError)
    end
  end

  describe "#staged_attributes" do
    it "returns hash of staged attribute names and values" do
      allow(subject).to receive(:loaded_attributes).and_return({
        foo: {},
        bar: { original: 11, changed: nil },
        baz: { original: 6, changed: 14 },
        nerf: { changed: 45 }
      })
      expect(subject.staged_attributes).to eq({ baz: 14, nerf: 45 })
    end
  end

  describe "#reset_attributes_and_associations_cache" do
    it "clears the associations and attributes caches" do
      subject.instance_variable_set(:@loaded_attributes, :some_attributes)
      subject.instance_variable_set(:@loaded_associations, :some_associations)
      subject.reset_attributes_and_associations_cache
      expect(subject.loaded_attributes).to be_empty
      expect(subject.loaded_associations).to be_empty
    end
  end

  describe "#save!" do
    it "updates staged attributes on worksheet and empties attribute and association cache" do
      allow(subject).to receive(:staged_attributes).and_return(:the_staged_attributes)
      expect(worksheet).to receive(:update_attributes_at_row_position).
        with(:the_staged_attributes, row_position: 3).ordered
      expect(subject).to receive(:reset_attributes_and_associations_cache).ordered
      subject.save!
    end
  end

  describe "#spreadsheet" do
    it "delegates to worksheet" do
      allow(worksheet).to receive(:spreadsheet).and_return(:the_spreadsheet)
      expect(subject.spreadsheet).to eq(:the_spreadsheet)
    end
  end

  describe "#attributes" do
    it "returns hash of attributes not including associations" do
      row_class.attribute :foo
      row_class.attribute :bar
      row_class.has_one :furb, from_collection: :furbs, key: :furb_id

      allow(subject).to receive(:foo).and_return("yay")
      allow(subject).to receive(:bar).and_return(nil)
      expect(subject.attributes).to eq({ foo: "yay", bar: nil })
    end
  end

  describe "#associations" do
    it "returns hash of associations only" do
      row_class.attribute :foo
      row_class.has_one :furb, from_collection: :furbs, key: :furb_id
      row_class.has_many :ghosts, from_collection: :ghosts, key: :ghost_ids

      allow(subject).to receive(:furb).and_return("a_furb")
      allow(subject).to receive(:ghosts).and_return([:g1, :g2])
      expect(subject.associations).to eq({ furb: "a_furb", ghosts: [:g1, :g2] })
    end
  end

  describe "#to_hash" do
    it "returns only attributes by default" do
      allow(subject).to receive(:attributes).and_return({ attr: :val })
      expect(subject.to_hash).to eq({ attr: :val })
    end

    it "includes cascading associations with decreasing depth when given a depth level" do
      w1, w2, furb = double, double, double
      allow(w1).to receive(:to_hash).with(depth: 3).and_return(:w1_hash)
      allow(w2).to receive(:to_hash).with(depth: 3).and_return(:w2_hash)
      allow(furb).to receive(:to_hash).with(depth: 3).and_return(:furb_hash)
      allow(subject).to receive(:attributes).and_return({ my: :values })
      allow(subject).to receive(:associations).and_return({
        widgets: [w1, w2],
        furb: furb
      })
      expect(subject.to_hash(depth: 4)).to eq({
        my: :values, widgets: [ :w1_hash, :w2_hash ], furb: :furb_hash
      })
    end
  end
end
