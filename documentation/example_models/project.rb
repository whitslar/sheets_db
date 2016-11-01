class Project < SheetsDB::Spreadsheet
  has_many :tasks, worksheet_name: "Tasks", class_name: "Task"
  has_many :users, worksheet_name: "Users", class_name: "User"
  has_many :pets, worksheet_name: "Pets", class_name: "Pet"
  belongs_to_many :teams, class_name: "Team"
end
