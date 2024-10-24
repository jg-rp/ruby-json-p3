# frozen_string_literal: true

require "test_helper"

class TestIndexSelector < Minitest::Test
  def test_select_null
    path = JSONP3.compile("$[1]")

    assert_equal([nil], path.find(["a", nil, "b"]).map(&:value))
  end
end
