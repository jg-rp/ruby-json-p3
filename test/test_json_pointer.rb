# frozen_string_literal: true

require "test_helper"

class TestJSONPointer < Minitest::Test
  def test_to_string
    pointer = JSONP3::JSONPointer.new("/some/thing/1")

    assert_equal("/some/thing/1", pointer.to_s)
  end

  def test_missing_key
    pointer = JSONP3::JSONPointer.new("/some/other")
    data = { "some" => { "thing" => "else" } }

    assert_raises(JSONP3::JSONPointerKeyError) { pointer.resolve(data) }
  end

  def test_index_out_of_range
    pointer = JSONP3::JSONPointer.new("/some/thing/7")
    data = { "some" => { "thing" => [1, 2, 3] } }

    assert_raises(JSONP3::JSONPointerIndexError) { pointer.resolve(data) }
  end

  def test_property_of_string
    pointer = JSONP3::JSONPointer.new("/some/thing/else")
    data = { "some" => { "thing" => "foo" } }

    assert_raises(JSONP3::JSONPointerTypeError) { pointer.resolve(data) }
  end

  def test_resolve_with_default
    pointer = JSONP3::JSONPointer.new("/some/other")
    data = { "some" => { "thing" => "else" } }

    assert_nil(pointer.resolve(data, fallback: nil))
    assert_equal(42, pointer.resolve(data, fallback: 42))
  end

  def test_no_leading_slash
    assert_raises(JSONP3::JSONPointerSyntaxError) { JSONP3::JSONPointer.new("some/other") }
  end

  def test_convenience_resolve
    assert_equal(42, JSONP3.resolve("/some/thing", { "some" => { "thing" => 42 } }))
  end

  def test_convenience_resolve_with_default
    assert_equal(7, JSONP3.resolve("/some/other", { "some" => { "thing" => 42 } }, fallback: 7))
  end

  def test_trailing_slash
    pointer = JSONP3::JSONPointer.new("/foo/")
    data = { "foo" => { "" => [1, 2, 3], " " => [4, 5, 6] } }

    assert_equal([1, 2, 3], pointer.resolve(data))
  end

  def test_trailing_whitespace
    pointer = JSONP3::JSONPointer.new("/foo/ ")
    data = { "foo" => { "" => [1, 2, 3], " " => [4, 5, 6] } }

    assert_equal([4, 5, 6], pointer.resolve(data))
  end

  def test_index_with_leading_zero
    pointer = JSONP3::JSONPointer.new("/some/thing/01")
    data = { "some" => { "thing" => [1, 2, 3] } }

    assert_raises(JSONP3::JSONPointerTypeError) { pointer.resolve(data) }
  end
end
