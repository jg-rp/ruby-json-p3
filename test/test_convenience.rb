# frozen_string_literal: true

require "test_helper"

class TestConvenienceMethods < Minitest::Spec
  def test_compile
    path = JSONP3.compile("$.a.b")
    data = { "a" => { "b" => 42 } }
    nodes = path.find(data)
    _(nodes.map(&:value)).must_equal([42])
  end

  def test_find
    data = { "a" => { "b" => 42 } }
    nodes = JSONP3.find("$.a.b", data)
    _(nodes.map(&:value)).must_equal([42])
  end

  def test_find_enum
    data = { "a" => { "b" => 42 } }
    nodes = JSONP3.find_enum("$.a.b", data).to_a
    _(nodes.map(&:value)).must_equal([42])
  end

  def test_match
    data = { "a" => [1, 2, 3, 4] }
    node = JSONP3.match("$.a.*", data)
    _(node.value).must_equal(1)
  end

  def test_no_match
    data = { "a" => [1, 2, 3, 4] }
    node = JSONP3.match("$.b.*", data)

    assert_nil(node)
  end

  def test_first
    data = { "a" => [1, 2, 3, 4] }
    node = JSONP3.first("$.a.*", data)
    _(node.value).must_equal(1)
  end

  def test_no_first
    data = { "a" => [1, 2, 3, 4] }
    node = JSONP3.first("$.b.*", data)

    assert_nil(node)
  end

  def test_match?
    data = { "a" => [1, 2, 3, 4] }
    node = JSONP3.match?("$.a.*", data)

    _(node).must_equal(true)
  end

  def test_no_match?
    data = { "a" => [1, 2, 3, 4] }
    node = JSONP3.match?("$.b.*", data)

    _(node).must_equal(false)
  end
end
