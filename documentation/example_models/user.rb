class User < SheetsDB::Worksheet::Row
  attribute :id, type: Integer
  attribute :first_name
  attribute :last_name
  attribute :pet_ids, multiple: true

  has_many :pets, from_collection: :pets, key: :pet_ids

  belongs_to_many :created_tasks, from_collection: :tasks, foreign_key: :creator_id
end
