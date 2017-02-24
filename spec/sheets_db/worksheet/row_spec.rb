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
    context "dynamic methods" do
      before(:each) do
        allow(worksheet).to receive(:attribute_at_row_position).with(:foo, 3).once.and_return("the_number_1")
        row_class.attribute :foo
      end

      it "sets up memoized reader for attribute" do
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
    end

    it "raises an error if attribute already registered" do
      row_class.attribute :foo
      expect {
        row_class.attribute :foo
      }.to raise_error(described_class::AttributeAlreadyRegisteredError)
    end

    it "sets default configuration on attribute definition" do
      row_class.attribute :the_name
      expect(row_class.attribute_definitions.fetch(:the_name)).to eq({
        type: String,
        multiple: false,
        transform: nil,
        column_name: "the_name",
        association: false
      })
    end

    it "allows overridden settings" do
      row_class.attribute :the_name, type: "foo", multiple: "sure", transform: "yeah", column_name: "Zoop"
      expect(row_class.attribute_definitions.fetch(:the_name)).to eq({
        type: "foo",
        multiple: "sure",
        transform: "yeah",
        column_name: "Zoop",
        association: false
      })
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

    it "sets up writer that adds foreign keys and memoized association" do
      subject.id = 12
      w1, w2 = double(:w1, this_id: 13), double(:w2, this_id: 14)
      subject.loaded_associations[:widgets] = []
      expect(w1).to receive(:add_element_to_attribute).with(:this_id, 12)
      expect(w2).to receive(:add_element_to_attribute).with(:this_id, 12)
      subject.widgets = [w1, w2]
      expect(subject.changed_foreign_items).to match_array([w1, w2])
      expect(subject.widgets).to match_array([w1, w2])
    end

    it "removes existing relationships if not in new set" do
      subject.id = 12
      w1, w2, w3 = double(:w1, this_id: 12), double(:w2, this_id: 12), double(:w3, this_id: 13)
      subject.loaded_associations[:widgets] = [w1, w2]
      expect(w1).to receive(:remove_element_from_attribute).with(:this_id, 12)
      expect(w3).to receive(:add_element_to_attribute).with(:this_id, 12)
      subject.widgets = [w2, w3]
      expect(subject.changed_foreign_items).to match_array([w1, w3])
      expect(subject.widgets).to match_array([w2, w3])
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
      allow(spreadsheet).to receive(:find_associations_by_attribute).and_return([])
      subject.id = 12
      the_widget = double(:the_widget, this_id: 13)
      expect(the_widget).to receive(:add_element_to_attribute).with(:this_id, 12)
      subject.widget = the_widget
      expect(subject.widget).to eq(the_widget)
    end

    it "removes old association" do
      subject.id = 12
      old_widget, new_widget = double(:old, this_id: 12), double(:new, this_id: 14)
      subject.loaded_associations[:widget] = old_widget
      expect(old_widget).to receive(:remove_element_from_attribute).with(:this_id, 12)
      expect(new_widget).to receive(:add_element_to_attribute).with(:this_id, 12)
      subject.widget = new_widget
      expect(subject.widget).to eq(new_widget)
    end

    it "raises an error if attribute already registered" do
      expect {
        row_class.belongs_to_one :widget, from_collection: :widgets, foreign_key: :widget_id
      }.to raise_error(described_class::AttributeAlreadyRegisteredError)
    end
  end

  describe "#stage_attributes" do
    it "sends setter method for each attribute given" do
      expect(subject).to receive(:foo=).with(:new_foo)
      expect(subject).to receive(:bar=).with(:new_bar)
      subject.stage_attributes(foo: :new_foo, bar: :new_bar)
    end
  end

  describe "#update_attributes!" do
    it "stages given attributes and calls #save!" do
      expect(subject).to receive(:stage_attributes).with({
        foo: :new_foo, bar: :new_bar
      })
      expect(subject).to receive(:save!)
      subject.update_attributes!(foo: :new_foo, bar: :new_bar)
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

  describe "#save_changed_foreign_items!" do
    it "sends save! method to all changed foreign items" do
      fi1, fi2 = double, double
      allow(subject).to receive(:changed_foreign_items).and_return([fi1, fi2])
      expect(fi1).to receive(:save!)
      expect(fi2).to receive(:save!)
      subject.save_changed_foreign_items!
    end
  end

  describe "#save!" do
    it "updates staged attributes, foreign item changes, and attribute and association cache" do
      allow(subject).to receive(:staged_attributes).and_return(:the_staged_attributes)
      expect(worksheet).to receive(:update_attributes_at_row_position).
        with(:the_staged_attributes, row_position: 3).ordered
      expect(subject).to receive(:save_changed_foreign_items!)
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

  describe "#add_element_to_attribute" do
    context "with singular attribute" do
      before(:each) do
        row_class.attribute :foo
      end

      it "sets the attribute to the given element" do
        allow(subject).to receive(:get_persisted_attribute).with(:foo).and_return(nil)
        subject.add_element_to_attribute(:foo, "hello")
        expect(subject.foo).to eq("hello")
      end

      it "does nothing if attribute already is element" do
        allow(subject).to receive(:get_persisted_attribute).with(:foo).and_return("hello")
        expect(subject).to receive(:foo=).never
        subject.add_element_to_attribute(:foo, "hello")
        expect(subject.foo).to eq("hello")
      end
    end

    context "with multiple attribute" do
      before(:each) do
        row_class.attribute :foo, multiple: true
      end

      it "adds the given element to the attribute" do
        allow(subject).to receive(:get_persisted_attribute).with(:foo).and_return([1, 2])
        subject.add_element_to_attribute(:foo, 3)
        expect(subject.foo).to eq([1, 2, 3])
      end

      it "does nothing if attribute already contains element" do
        allow(subject).to receive(:get_persisted_attribute).with(:foo).and_return([1, 2, 3])
        expect(subject).to receive(:foo=).never
        subject.add_element_to_attribute(:foo, 3)
        expect(subject.foo).to eq([1, 2, 3])
      end
    end
  end

  describe "#remove_element_from_attribute" do
    context "with singular attribute" do
      before(:each) do
        row_class.attribute :foo
      end

      it "sets the attribute to nil" do
        allow(subject).to receive(:get_persisted_attribute).with(:foo).and_return("hello")
        subject.remove_element_from_attribute(:foo, "hello")
        expect(subject.foo).to be_nil
      end

      it "does nothing if attribute not set to element" do
        allow(subject).to receive(:get_persisted_attribute).with(:foo).and_return("bye")
        subject.remove_element_from_attribute(:foo, "hello")
        expect(subject.foo).to eq("bye")
      end
    end

    context "with multiple attribute" do
      before(:each) do
        row_class.attribute :foo, multiple: true
      end

      it "removes the given element from the attribute" do
        allow(subject).to receive(:get_persisted_attribute).with(:foo).and_return([1, 2, 3])
        subject.remove_element_from_attribute(:foo, 3)
        expect(subject.foo).to eq([1, 2])
      end

      it "does nothing if attribute does not contain element" do
        allow(subject).to receive(:get_persisted_attribute).with(:foo).and_return([1, 2, 3])
        subject.remove_element_from_attribute(:foo, 4)
        expect(subject.foo).to eq([1, 2, 3])
      end
    end
  end
end
