class Pet < SheetsDB::Worksheet::Row
  attribute :id
  attribute :first_name, transform: ->(first_name) { first_name.upcase }
  attribute :favorite_colors, aliases: [:favorite_colours], multiple: true

  belongs_to_one :parent, from_collection: :users, foreign_key: :pet_ids
end
