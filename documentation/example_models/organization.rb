class Organization < SheetsDB::Collection
  has_many :teams, class_name: "Team"
end