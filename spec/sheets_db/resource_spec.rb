RSpec.describe SheetsDB::Resource do
  let(:raw_file) { GoogleDriveSessionProxy::DUMMY_FILES[:file]}
  let(:test_class) { Class.new(described_class) }

  subject { test_class.new(raw_file) }

  describe ".resource_type" do
    it "inherits from parent class" do
      test_class.set_resource_type :pigeons
      new_class = Class.new(test_class)
      expect(new_class.resource_type).to eq(:pigeons)
    end

    it "can be overridden by subclass" do
      test_class.set_resource_type :pigeons
      new_class = Class.new(test_class)
      new_class.set_resource_type :snoopies
      expect(new_class.resource_type).to eq(:snoopies)
    end
  end

  describe ".find_by_id" do
    it "returns instance for given id" do
      expect(test_class.find_by_id(:file)).to eq(subject)
    end

    it "raises error if id does not represent class's resource type" do
      allow(test_class).to receive(:resource_type).and_return(GoogleDrive::Spreadsheet)
      expect {
        test_class.find_by_id(:file)
      }.to raise_error(described_class::ResourceTypeMismatchError)
    end
  end

  describe "#id" do
    it "delegates to raw resource" do
      allow(raw_file).to receive(:id).and_return(:foo)
      expect(subject.id).to eq(:foo)
    end
  end

  describe "#name" do
    it "delegates to raw resource" do
      allow(raw_file).to receive(:name).and_return(:foo)
      expect(subject.name).to eq(:foo)
    end
  end

  describe "#created_at" do
    it "delegates to raw resource #created_time" do
      allow(raw_file).to receive(:created_time).and_return(:foo)
      expect(subject.created_at).to eq(:foo)
    end
  end

  describe "#updated_at" do
    it "delegates to raw resource #modified_time" do
      allow(raw_file).to receive(:modified_time).and_return(:foo)
      expect(subject.updated_at).to eq(:foo)
    end
  end

  describe ".belongs_to_many" do
    it "adds an association of parents" do
      test_association_class = Class.new(SheetsDB::Collection)
      allow(SheetsDB::Support).to receive(:constantize).with("Goose").and_return(test_association_class)
      test_class.belongs_to_many :worlds, class_name: "Goose"
      allow(raw_file).
        to receive(:parents).
        and_return([:foo, :bar])
      allow(test_association_class).to receive(:find_by_id).with(:foo).and_return(:foo_parent)
      allow(test_association_class).to receive(:find_by_id).with(:bar).and_return(:bar_parent)
      expect(subject.worlds).to eq([:foo_parent, :bar_parent])
    end

    it "does not allow two parent associations" do
      expect {
        test_class.belongs_to_many :teams, class_name: "Foo"
        test_class.belongs_to_many :cadres, class_name: "Bar"
      }.to raise_error(described_class::CollectionTypeAlreadyRegisteredError)
    end
  end

  describe ".association_methods_for_type" do
    it "raises ArgumentError if unrecognized association type" do
      expect {
        test_class.association_methods_for_type(:furbies)
      }.to raise_error(ArgumentError)
    end

    it "returns object with find & create methods for spreadsheet type" do
      method_object = test_class.association_methods_for_type(:spreadsheet)
      expect(method_object.find).to eq(:file_by_title)
      expect(method_object.create).to eq(:create_spreadsheet)
    end

    it "returns object with find & create methods for worksheet type" do
      method_object = test_class.association_methods_for_type(:worksheet)
      expect(method_object.find).to eq(:worksheet_by_title)
      expect(method_object.create).to eq(:add_worksheet)
    end

    it "returns object with find & create methods for subcollection type" do
      method_object = test_class.association_methods_for_type(:subcollection)
      expect(method_object.find).to eq(:subcollection_by_title)
      expect(method_object.create).to eq(:create_subcollection)
    end
  end

  describe "#base_attributes" do
    it "returns hash of common resource attributes" do
      allow(subject).to receive(:id).and_return(12)
      allow(subject).to receive(:name).and_return("Riverboat")
      allow(subject).to receive(:created_at).and_return(:a_while_ago)
      allow(subject).to receive(:updated_at).and_return(:recently)
      expect(subject.base_attributes).to eq({
        id: 12,
        name: "Riverboat",
        created_at: :a_while_ago,
        updated_at: :recently
      })
    end
  end

  describe "#==" do
    it "returns true if google drive resource is the same" do
      expect(subject).to eq(test_class.new(raw_file))
    end

    it "returns false if other is not a resource" do
      expect(subject).not_to eq(double("Something Else", google_drive_resource: raw_file))
    end

    it "returns false if google drive resource is different" do
      expect(subject).not_to eq(test_class.new(
        GoogleDrive::File.new(self, "file")
      ))
    end
  end

  describe "#reload!" do
    it "reloads the google_drive_resource and resets memoization" do
      subject.instance_variable_set(:@associated_resources, :whatever)
      subject.instance_variable_set(:@anonymous_resources, :thingamajig)
      expect(raw_file).to receive(:reload_metadata)
      subject.reload!
      expect(subject.instance_variable_get(:@associated_resources)).to be_nil
      expect(subject.instance_variable_get(:@anonymous_resources)).to be_nil
    end
  end

  describe "#delete!" do
    it "deletes the google_drive_resource" do
      expect(raw_file).to receive(:delete)
      subject.delete!
    end
  end

  describe "#eql?" do
    it "aliases to ==" do
      expect(subject.method(:eql?)).to eq(subject.method(:==))
    end
  end

  describe "#hash" do
    it "returns hash of class and google drive resource" do
      expect(subject.hash).to eq(
        [test_class, raw_file].hash
      )
    end
  end

  describe "#find_child_google_drive_resource_by" do
    let(:raw_file) { double("Google Drive Resource") }

    before do
      allow(test_class).to receive(:association_methods_for_type).
        with(:the_type).
        and_return(OpenStruct.new(find: :the_find_method, create: :the_create_method))
    end

    it "returns child resource of given type and title" do
      allow(raw_file).to receive(:the_find_method).with(:the_title).and_return(:the_resource)
      expect(
        subject.find_child_google_drive_resource_by(type: :the_type, title: :the_title)
      ).to eq(:the_resource)
    end

    it "creates new child resource of given type and title if not found and create is true" do
      allow(raw_file).to receive(:the_find_method).with(:the_title).and_return(nil)
      allow(raw_file).to receive(:the_create_method).with(:the_title).and_return(:the_new_resource)
      expect(
        subject.find_child_google_drive_resource_by(type: :the_type, title: :the_title, create: true)
      ).to eq(:the_new_resource)
    end

    it "raises exception if resource not found and create is false" do
      allow(raw_file).to receive(:the_find_method).with(:the_title).and_return(nil)
      expect {
        subject.find_child_google_drive_resource_by(type: :the_type, title: :the_title)
      }.to raise_error(test_class::ChildResourceNotFoundError)
    end
  end
end
