class Team < SheetsDB::Collection
  has_many :projects, class_name: "Project", resource_type: :spreadsheets
  belongs_to_many :organizations, class_name: "Organization"

  def organization
    organizations.first
  end
end
