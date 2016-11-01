class Task < SheetsDB::Worksheet::Row
  attribute :id, type: Integer
  attribute :name
  attribute :creator_id, type: Integer
  attribute :assignee_id, type: Integer
  attribute :finished_at, type: DateTime

  has_one :creator, from_collection: :users, key: :creator_id
  has_one :assignee, from_collection: :users, key: :assignee_id
end
