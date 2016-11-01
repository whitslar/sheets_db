# SheetsDB

SheetsDB is essentially a Ruby ORM for tabular and relational data stored in Google Sheets.  While storing relational data in a spreadsheet is kind of like using a pint glass to hammer a nail, there are situations in which this can be useful, especially for prototyping or collaborating with people who aren't as comfortable seeding data into an RDBMS.

There are some conventions you must follow in your Google drive folders and the Sheets themselves, but most setup of attributes, primitive type mapping, etc. is done within your object classes themselves.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sheets_db'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sheets_db

## Usage

View usage documentation [here](documentation/usage.md).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ablschools/sheets_db. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

