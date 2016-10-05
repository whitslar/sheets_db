require 'simplecov'
SimpleCov.start

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'sheets_db'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.expose_dsl_globally = false
  config.order = 'random'

  config.before(:suite) do
    SheetsDB::Session.default = SheetsDB::Session.new(GoogleDriveSessionProxy.new)
  end
end
