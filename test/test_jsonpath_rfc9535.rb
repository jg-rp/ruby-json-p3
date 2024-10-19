# frozen_string_literal: true

require "test_helper"

class TestJSONPathRFC9535 < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::JSONPathRFC9535::VERSION
  end
end
