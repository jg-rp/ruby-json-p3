# frozen_string_literal: true

require "test_helper"

class TestNormalizedPath < Minitest::Test
  def test_normalize_negative_index
    path = JSONP3.compile("$.a[-2]")
    data = { "a" => [1, 2, 3, 4, 5] }
    nodes = path.find(data)

    assert_equal(1, nodes.length)
    assert_equal("$['a'][3]", nodes.first.path)
  end

  def test_normalize_reverse_slice
    path = JSONP3.compile("$.a[3:0:-1]")
    data = { "a" => [1, 2, 3, 4, 5] }
    nodes = path.find(data)

    assert_equal(3, nodes.length)
    assert_equal(["$['a'][3]", "$['a'][2]", "$['a'][1]"], nodes.map(&:path))
  end
end
