require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'sheets_db'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.expose_dsl_globally = false
  config.order = 'random'
end
