# frozen_string_literal: true

require "test_helper"

class TestJSONP3 < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::JSONP3::VERSION
  end
end
