ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

# HACK: get rid of those stupid warnings in test runs (marcel gem)
module Warning
  class << self
    alias_method :__original_warn, :warn
    def warn(message)
      return if message.include?("literal string will be frozen in the future")
      __original_warn(message)
    end
  end
end


module ActiveSupport
  class TestCase
    include FactoryBot::Syntax::Methods

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Add more helper methods to be used by all tests here...
  end
end
