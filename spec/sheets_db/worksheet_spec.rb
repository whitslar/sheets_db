require 'bigdecimal'

RSpec.describe SheetsDB::Worksheet do
  let(:raw_worksheet) { instance_double(GoogleDrive::Worksheet, title: "The Worksheet") }
  let(:spreadsheet) { GoogleDriveSessionProxy::DUMMY_FILES[:spreadsheet] }
  let(:row_class) { Class.new(SheetsDB::Worksheet::Row) }

  subject { described_class.new(spreadsheet: spreadsheet, google_drive_resource: raw_worksheet, type: row_class) }

  describe "#type" do
    it "returns type from initialization" do
      expect(subject.type).to eq(row_class)
    end

    context "when no type given in initialization" do
      subject { described_class.new(spreadsheet: spreadsheet, google_drive_resource: raw_worksheet) }

      it "returns memoized generated Row type using columns if no type in initialization" do
        allow(subject).to receive(:column_names).and_return(["first", "second"])
        generated_type_class = subject.type
        expect(generated_type_class.attribute_definitions.keys).to eq(%i[first second])
      end
    end
  end

  describe "#set_up!" do
    it "seeds column headers if sheet is totally empty" do
      allow(raw_worksheet).to receive(:num_rows).and_return(0)
      allow(subject).to receive(:attribute_definitions).and_return({
        foo: { column_name: "foo" },
        bar: { column_name: "bar" }
      })
      expect(subject).to receive(:write_matrix!).with([["foo", "bar"]])
      expect(subject.set_up!).to eq(subject)
      expect(subject.google_drive_resource).to eq(raw_worksheet)
    end
  end

  describe "#attribute_at_row_position" do
    it "returns the value for the given attribute at the given row index" do
      allow(subject).to receive(:get_definition_and_column).
        with(:first_name).
        and_return([
          :the_definition,
          SheetsDB::Worksheet::Column.new(name: :the_column, column_position: 4)
        ])
      allow(subject).to receive(:read_value_from_google_drive_resource).
        with(dimensions: [2, 4], attribute_definition: :the_definition).
        and_return(:the_attribute_value)
      expect(subject.attribute_at_row_position(:first_name, 2)).to eq(:the_attribute_value)
    end

    it "returns value_if_column_missing if column not found" do
      allow(subject).to receive(:get_definition_and_column).
        with(:first_name).
        and_return([
          :the_definition,
          nil
        ])
      allow(subject).to receive(:value_if_column_missing).with(:the_definition).and_return(:the_missing_value)
      expect(subject.attribute_at_row_position(:first_name, 2)).to eq(:the_missing_value)
    end
  end

  describe "#read_value_from_google_drive_resource" do
    it "converts the given value according to type" do
      allow(raw_worksheet).to receive(:[]).with(2, 3).and_return("Anna")
      allow(subject).to receive(:convert_value).with("Anna", { type: :the_type }).and_return("Deanna")
      expect(
        subject.read_value_from_google_drive_resource(
          dimensions: [2, 3],
          attribute_definition: { type: :the_type }
        )
      ).to eq("Deanna")
    end

    it "splits multiple return values" do
      allow(raw_worksheet).to receive(:[]).with(4, 6).and_return("Anna, Banana")
      allow(subject).to receive(:convert_value).with("Anna", { type: :the_type, multiple: true }).and_return("Deanna")
      allow(subject).to receive(:convert_value).with("Banana", { type: :the_type, multiple: true }).and_return("The Banana")
      expect(
        subject.read_value_from_google_drive_resource(
          dimensions: [4, 6],
          attribute_definition: { type: :the_type, multiple: true }
        )
      ).to eq(["Deanna", "The Banana"])
    end

    it "reads input values directly if type is DateTime" do
      allow(raw_worksheet).to receive(:input_value).with(1, 3).and_return("April 15")
      allow(subject).to receive(:convert_value).with("April 15", { type: DateTime }).and_return("4/15")
      expect(
        subject.read_value_from_google_drive_resource(
          dimensions: [1, 3],
          attribute_definition: { type: DateTime }
        )
      ).to eq("4/15")
    end
  end

  describe "#value_if_column_missing" do
    it "raises a ColumnNotFoundError if no if_column_missing proc" do
      definition = { column_name: "Wrong Column" }
      expect {
        subject.value_if_column_missing(definition)
      }.to raise_error(described_class::ColumnNotFoundError, "Wrong Column")
    end

    it "returns results of if_column_missing proc" do
      row_class.attribute :wow
      definition = {
        column_name: "Wrong Column",
        if_column_missing: Proc.new { wow }
      }
      allow(subject).to receive(:wow).and_return(:the_missing_value)
      expect(subject.value_if_column_missing(definition)).to eq(:the_missing_value)
    end
  end

  describe "#update_attributes_at_row_position" do
    it "updates the given attributes and synchronizes" do
      expect(subject).to receive(:update_attribute_at_row_position).
        with(attribute_name: :first_name, value: "Bonnie", row_position: 2)
      expect(subject).to receive(:update_attribute_at_row_position).
        with(attribute_name: :last_name, value: "McFragile", row_position: 2)
      expect(subject).to receive(:synchronize!)
      subject.update_attributes_at_row_position(
        { first_name: "Bonnie", last_name: "McFragile" },
        row_position: 2
      )
    end

    it "updates given attributes but does not synchronize if delaying sync" do
      allow(subject).to receive(:synchronizing).and_return(false)
      expect(subject).to receive(:update_attribute_at_row_position).
        with(attribute_name: :first_name, value: "Bonnie", row_position: 2)
      expect(subject).not_to receive(:synchronize!)
      subject.update_attributes_at_row_position({ first_name: "Bonnie" }, row_position: 2)
    end
  end

  describe "#update_attribute_at_row_position" do
    it "updates the given attribute using the google drive resource" do
      allow(subject).to receive(:get_definition_and_column).
        with(:last_name).
        and_return([
          { foo: :bar },
          SheetsDB::Worksheet::Column.new(name: :the_column, column_position: 4)
        ])
      expect(raw_worksheet).to receive(:[]=).with(2, 4, "McFragile")
      subject.update_attribute_at_row_position(
        attribute_name: :last_name,
        value: "McFragile",
        row_position: 2
      )
    end

    it "joins multiple attributes using commas before updating" do
      allow(subject).to receive(:get_definition_and_column).
        with(:colors).
        and_return([
          { multiple: true },
          SheetsDB::Worksheet::Column.new(name: :the_column, column_position: 5)
        ])
      expect(raw_worksheet).to receive(:[]=).with(2, 5, "green,white")
      subject.update_attribute_at_row_position(
        attribute_name: :colors,
        value: %w[green white],
        row_position: 2
      )
    end

    it "raises a ColumnNotFoundError if accessing a column that does not exist" do
      allow(subject).to receive(:get_definition_and_column).with(:first_name).and_return([:the_definition, nil])
      expect {
        subject.update_attribute_at_row_position(attribute_name: :first_name, value: "zop", row_position: 2)
      }.to raise_error(described_class::ColumnNotFoundError)
    end
  end

  describe "#new" do
    let(:new_row) { instance_double(SheetsDB::Worksheet::Row) }

    it "returns new instance of type with unset row_position" do
      allow(row_class).to receive(:new).with(worksheet: subject, row_position: nil).
        and_return(new_row)
      allow(new_row).to receive(:stage_attributes).with({})
      expect(subject.new).to eq(new_row)
    end

    it "pre-stages given attributes on new row" do
      allow(row_class).to receive(:new).with(worksheet: subject, row_position: nil).
        and_return(new_row)
      allow(new_row).to receive(:stage_attributes).with({ foo: :bar })
      expect(subject.new(foo: :bar)).to eq(new_row)
    end
  end

  describe "#create!" do
    it "returns #new row after calling #save!" do
      new_row = instance_double(SheetsDB::Worksheet::Row)
      allow(subject).to receive(:new).with(foo: :bar).and_return(new_row)
      allow(new_row).to receive(:save!).and_return(:saved_row)
      expect(subject.create!(foo: :bar)).to eq(:saved_row)
    end
  end

  describe "#import!" do
    it "in transaction, creates records for each set of attributes in given array" do
      expect(subject).to receive(:disable_synchronization!).ordered
      expect(subject).to receive(:create!).with(foo: :bar).ordered
      expect(subject).to receive(:create!).with(baz: :narf).ordered
      expect(subject).to receive(:synchronize!).ordered
      expect(subject).to receive(:enable_synchronization!).ordered
      subject.import!([{ foo: :bar }, { baz: :narf }])
    end
  end

  describe "finder methods" do
    let(:rows) {[
      double(SheetsDB::Worksheet::Row, id: 1, fub: :a),
      double(SheetsDB::Worksheet::Row, id: 2, fub: :a),
      double(SheetsDB::Worksheet::Row, id: 3, fub: :b),
      double(SheetsDB::Worksheet::Row, id: 4, fub: :c)
    ]}

    before do
      allow(raw_worksheet).to receive(:num_rows).and_return(5)
      rows.each_with_index do |row, index|
        allow(row_class).to receive(:new).with(worksheet: subject, row_position: index + 2).and_return(row)
      end
    end

    describe "#all" do
      it "returns instances of type for each row in worksheet" do
        expect(subject.all).to eq(rows)
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
        expect(subject.find_by_ids([2, 3])).to eq(rows.values_at(1, 2))
      end
    end

    describe "#find_by_attribute" do
      it "returns rows with matching attribute value" do
        allow(subject).to receive(:attribute_definitions).and_return(fub: {})
        expect(subject.find_by_attribute(:fub, :a)).to eq(rows.values_at(0, 1))
      end
    end
  end

  describe "#columns" do
    it "returns memoized columns with names and positions" do
      allow(raw_worksheet).to receive(:rows).once.and_return([
        ["id", "", "first_name", "last_name"]
      ])
      subject.columns
      expect(subject.columns).to eq({
        "id" => SheetsDB::Worksheet::Column.new(name: "id", column_position: 1),
        "first_name" => SheetsDB::Worksheet::Column.new(name: "first_name", column_position: 3),
        "last_name" => SheetsDB::Worksheet::Column.new(name: "last_name", column_position: 4),
      })
    end

    it "returns empty hash if worksheet is empty" do
      allow(raw_worksheet).to receive(:rows).once.and_return([])
      subject.columns
      expect(subject.columns).to eq({})
    end
  end

  describe "#column_names" do
    it "returns keys from columns" do
      allow(subject).to receive(:columns).and_return(
        "id" => :column_1,
        "first_name" => :column_2
      )
      expect(subject.column_names).to eq([
        "id",
        "first_name"
      ])
    end
  end

  describe "#attribute_definitions" do
    it "delegates to type" do
      allow(row_class).to receive(:attribute_definitions).and_return(:the_definitions)
      expect(subject.attribute_definitions).to eq(:the_definitions)
    end
  end

  describe "#get_definition_and_column" do
    before do
      allow(subject).to receive(:attribute_definitions).and_return(
        boogers: { column_name: "Boogies" },
        snoobs: { foo: :bar },
        possums: { aliases: [:epossums, :opossums] }
      )
      allow(subject).to receive(:columns).and_return(
        "Boogies" => :boogers_column,
        "snoobs" => :snoobs_column,
        "opossums" => :possums_column
      )
    end

    it "returns the attribute definition and column object for the given attribute name" do
      expect(
        subject.get_definition_and_column(:snoobs)
      ).to eq([
        { foo: :bar },
        :snoobs_column
      ])
    end

    it "utilizes custom column name if in definition" do
      expect(
        subject.get_definition_and_column(:boogers)
      ).to eq([
        { column_name: "Boogies" },
        :boogers_column
      ])
    end

    it "utilizes column aliases, returning value from first alias column found" do
      expect(
        subject.get_definition_and_column(:possums)
      ).to eq([
        { aliases: [:epossums, :opossums] },
        :possums_column
      ])
    end
  end

  describe "#reload!" do
    it "reloads the google_drive_resource worksheet and cleans up memoization" do
      subject.instance_variable_set(:@columns, :whatever)
      subject.instance_variable_set(:@existing_raw_data, :the_raw_data)
      expect(raw_worksheet).to receive(:reload)
      expect(subject.reload!).to eq(subject)
      expect(subject.instance_variable_get(:@columns)).to be_nil
      expect(subject.instance_variable_get(:@existing_raw_data)).to be_nil
    end
  end

  describe "#convert_value" do
    it "returns nil if given a blank string" do
      expect(subject.convert_value("", { type: :whatever })).to be_nil
    end

    it "returns stripped value if unrecognized type" do
      expect(subject.convert_value("  a string ", { type: :whatever })).to eq("a string")
    end

    it "returns unstripped value if strip is false" do
      expect(subject.convert_value("  a string ", { strip: false, type: :whatever })).to eq("  a string ")
    end

    it "returns integer value if type is Integer" do
      expect(subject.convert_value("14", { type: Integer })).to eq(14)
    end

    it "returns BigDecimal value if type is Decimal" do
      expect(subject.convert_value("1.54", { type: :Decimal })).to eq(BigDecimal.new("1.54"))
    end

    it "returns DateTime value if type is DateTime" do
      expect(subject.convert_value("4/15/2016 10:15:30", { type: DateTime })).to eq(
        DateTime.parse("2016-04-15 10:15:30")
      )
    end

    context "when type is Boolean" do
      it "returns results of calling #convert_to_boolean with raw_value" do
        allow(subject).to receive(:convert_to_boolean).with("the_value").and_return(:a_result)
        expect(subject.convert_value("the_value", { type: :Boolean })).to eq(:a_result)
      end
    end

    context "when given :transform Proc" do
      it "returns results of calling given Proc with converted value" do
        transform_proc = ->(value) { value + 1 }
        expect(subject.convert_value("3", { type: Integer, transform: transform_proc })).to eq(4)
      end
    end
  end

  describe "#convert_to_boolean" do
    it "returns true if value in truthy list" do
      expect(subject.convert_to_boolean("Y")).to eq(true)
      expect(subject.convert_to_boolean("Yes")).to eq(true)
      expect(subject.convert_to_boolean("true")).to eq(true)
      expect(subject.convert_to_boolean("1")).to eq(true)
    end

    it "returns false if value in falsy list" do
      expect(subject.convert_to_boolean("n")).to eq(false)
      expect(subject.convert_to_boolean("NO")).to eq(false)
      expect(subject.convert_to_boolean("fALSE")).to eq(false)
      expect(subject.convert_to_boolean("0")).to eq(false)
    end

    it "returns nil if the value is not in truthy or falsy lists" do
      expect(subject.convert_to_boolean(nil)).to be_nil
      expect(subject.convert_to_boolean("whatever")).to be_nil
      expect(subject.convert_to_boolean("")).to be_nil
    end
  end

  describe "#==" do
    it "returns true if google drive resource is the same and type is the same" do
      expect(subject).to eq(
        described_class.new(spreadsheet: spreadsheet, google_drive_resource: raw_worksheet, type: row_class)
      )
    end

    it "returns false if other is not the same class" do
      expect(subject).not_to eq(
        SheetsDB::Spreadsheet.new(google_drive_resource: raw_worksheet)
      )
    end

    it "returns false if google drive resource is the same but type is different" do
      expect(subject).not_to eq(
        described_class.new(spreadsheet: spreadsheet, google_drive_resource: raw_worksheet, type: :other)
      )
    end

    it "returns false if google drive resource is different" do
      other_sheet = instance_double(GoogleDrive::Worksheet, title: "The Other Sheet")
      expect(subject).not_to eq(
        described_class.new(spreadsheet: spreadsheet, google_drive_resource: other_sheet, type: row_class)
      )
    end
  end

  describe "#eql?" do
    it "aliases to ==" do
      expect(subject.method(:eql?)).to eq(subject.method(:==))
    end
  end

  describe "#hash" do
    it "returns hash of class, worksheet, and row position" do
      expect(subject.hash).to eq(
        [described_class, raw_worksheet, row_class].hash
      )
    end
  end

  describe "#next_available_row_position" do
    it "returns worksheet's row count + 1" do
      allow(raw_worksheet).to receive(:num_rows).and_return(6)
      expect(subject.next_available_row_position).to eq(7)
    end
  end

  describe "#transaction" do
    it "yields to given block with synchronizing set to false" do
      expect(subject).to receive(:disable_synchronization!).ordered
      expect(subject).to receive(:reload!).ordered
      expect(subject).to receive(:synchronize!).ordered
      expect(subject).to receive(:enable_synchronization!).ordered

      subject.transaction do
        subject.reload!
      end
    end

    it "does not synchronize, but restores synchronizing to true, if exception thrown" do
      expect(subject).to receive(:disable_synchronization!).ordered
      expect(subject).not_to receive(:synchronize!)
      expect(subject).to receive(:enable_synchronization!).ordered
      expect {
        subject.transaction do
          raise ArgumentError
        end
      }.to raise_error(ArgumentError)
    end
  end

  describe "#disable_synchronization!" do
    it "sets synchronizing to false" do
      expect(subject.synchronizing).to eq(true)
      subject.disable_synchronization!
      expect(subject.synchronizing).to eq(false)
    end
  end

  describe "#enable_synchronization!" do
    it "sets synchronizing to true" do
      subject.disable_synchronization!
      expect(subject.synchronizing).to eq(false)
      subject.enable_synchronization!
      expect(subject.synchronizing).to eq(true)
    end
  end

  describe "#delete_google_drive_resource!" do
    it "deletes google_drive_resource and reloads spreadsheet" do
      expect(raw_worksheet).to receive(:delete)
      expect(spreadsheet).to receive(:reload!)
      subject.delete_google_drive_resource!
      expect(subject.google_drive_resource).to be_nil
    end
  end

  describe "#truncate!" do
    it "clears google_drive_resource and reruns setup" do
      expect(subject).to receive(:clear_google_drive_resource!).ordered
      expect(subject).to receive(:set_up!).ordered
      expect(subject).to receive(:reload!).ordered
      subject.truncate!
    end
  end

  describe "#write_matrix" do
    it "updates worksheet cells with given matrix" do
      expect(raw_worksheet).to receive(:update_cells).with(1, 1, :the_matrix)
      subject.write_matrix(:the_matrix)
    end

    it "clears worksheet first if rewrite: true" do
      expect(subject).to receive(:clear_google_drive_resource).ordered
      expect(raw_worksheet).to receive(:update_cells).with(1, 1, :the_matrix).ordered
      subject.write_matrix(:the_matrix, rewrite: true)
    end

    it "synchronizes worksheet if save: true" do
      expect(subject).to receive(:clear_google_drive_resource).ordered
      expect(raw_worksheet).to receive(:update_cells).with(1, 1, :the_matrix).ordered
      expect(subject).to receive(:synchronize!).ordered
      subject.write_matrix(:the_matrix, rewrite: true, save: true)
    end
  end

  describe "#write_matrix!" do
    it "curries to #write_matrix with save: true" do
      expect(subject).to receive(:write_matrix).with(:the_matrix, rewrite: :maybe, save: true)
      subject.write_matrix!(:the_matrix, rewrite: :maybe)
    end
  end

  describe "#write_raw_data" do
    it "updates worksheet cells with hash values from array, using first keys as headers" do
      expect(subject).to receive(:write_matrix).
        with([[:col1, :col2], ["a1", "a2"], ["b1", "b2"]], rewrite: :maybe)
      subject.write_raw_data([
        { col1: "a1", col2: "a2" },
        { col1: "b1", col2: "b2" }
      ], rewrite: :maybe)
    end

    it "raises exception if hashes don't all have same keys" do
      expect {
        subject.write_raw_data([
          { col1: "a1", col2: "a2" },
          { col3: "b1", col4: "b2" }
        ])
      }.to raise_error(ArgumentError)
    end
  end

  describe "#write_raw_data!" do
    it "curries to #write_raw_data with save: true" do
      expect(subject).to receive(:write_raw_data).with(:the_data, rewrite: :maybe, save: true)
      subject.write_raw_data!(:the_data, rewrite: :maybe)
    end
  end

  describe "#clear_google_drive_resource" do
    before do
      allow(raw_worksheet).to receive(:num_rows).and_return(3)
      allow(raw_worksheet).to receive(:num_cols).and_return(5)
    end

    it "writes matrix of empty cells at size of current worksheet" do
      expect(subject).to receive(:write_matrix).with(Array.new(3, Array.new(5)), save: false)
      subject.clear_google_drive_resource
    end

    it "saves if given save: true" do
      expect(subject).to receive(:write_matrix).with(Array.new(3, Array.new(5)), save: true)
      subject.clear_google_drive_resource(save: true)
    end
  end

  describe "#clear_google_drive_resource!" do
    it "curries to #clear_google_drive_resource with save: true" do
      expect(subject).to receive(:clear_google_drive_resource).with(save: true)
      subject.clear_google_drive_resource!
    end
  end

  describe "#synchronize!" do
    it "synchronizes google_drive_resource and resets existing_raw_data" do
      subject.instance_variable_set(:@existing_raw_data, :the_raw_data)
      expect(raw_worksheet).to receive(:synchronize)
      subject.synchronize!
      expect(subject.instance_variable_get(:@existing_raw_data)).to be_nil
    end
  end

  describe "#existing_raw_data" do
    it "returns memoized data hash from rows in worksheet" do
      allow(raw_worksheet).to receive(:rows).once.and_return(
        [["col1", "col2"], ["a1", "a2"], ["b1", "b2"]]
      )
      subject.existing_raw_data
      expect(subject.existing_raw_data).to eq([
        { "col1" => "a1", "col2" => "a2" },
        { "col1" => "b1", "col2" => "b2" }
      ])
    end
  end
end
