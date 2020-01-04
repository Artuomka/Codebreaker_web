require 'rack/test'
require 'simplecov'

require_relative '../dependencies'

SimpleCov.start do
  minimum_coverage 95
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
end