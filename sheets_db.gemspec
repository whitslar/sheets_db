# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sheets_db/version'

Gem::Specification.new do |spec|
  spec.name          = "sheets_db"
  spec.version       = SheetsDB::VERSION
  spec.authors       = ["Ravi Gadad"]
  spec.email         = ["ravi@ablschools.com"]

  spec.summary       = %q{Adapter for pseudo-relational data stored in Google Sheets}
  spec.homepage      = "https://github.com/ablschools/sheets_db"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "google_drive_maintained", "3.0.11"

  spec.add_development_dependency "bundler", "~> 2.4"
  spec.add_development_dependency "rake", "~> 13"
  spec.add_development_dependency "rspec", "~> 3.11"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "guard-rspec"
end
