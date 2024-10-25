# frozen_string_literal: true

require "test_helper"

class MockEnvironment < JSONP3::JSONPathEnvironment
  MAX_RECURSION_DEPTH = 3
end

class TestErrors < Minitest::Test
  def test_recursive_data
    path = JSONP3.compile("$..a")
    array = []
    data = { "foo" => array }
    array << data

    assert_raises(JSONP3::JSONPathRecursionError) { path.find(data) }
  end

  def test_low_recursion_limit
    env = MockEnvironment.new
    path = env.compile("$..a")
    data = { "foo" => [{ "bar" => [1, 2, 3] }] }

    assert_raises(JSONP3::JSONPathRecursionError) { path.find(data) }
  end
end
