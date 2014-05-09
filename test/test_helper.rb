# encoding: UTF-8
unless ENV['DISABLE_RCOV']
  require 'simplecov'
  require 'simplecov-rcov'

  SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
  SimpleCov.start 'rails'
end

ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

require 'minitest/unit'
require 'minitest/autorun'

require 'mocha/setup'

require 'webmock/minitest'
WebMock.disable_net_connect!(:allow_localhost => true)

class MiniTest::Unit::TestCase
  include Shoulda::InstanceMethods
  extend Shoulda::ClassMethods
  include Shoulda::Assertions
  extend Shoulda::Macros
  include Shoulda::Helpers

  def teardown_with_customisations
    teardown_without_customisations
    Timecop.return
    WorldLocation.reset_cache
  end
  alias_method_chain :teardown, :customisations
end

require 'gds_api/test_helpers/json_client_helper'

def fixture_file(filename)
  File.expand_path("../fixtures/#{filename}", __FILE__)
end

def read_fixture_file(filename)
  File.read(fixture_file(filename))
end
