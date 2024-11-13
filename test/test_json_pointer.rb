# frozen_string_literal: true

require "test_helper"

class TestJSONPointer < Minitest::Test
  def test_to_string
    pointer = JSONP3::JSONPointer.new("/some/thing/1")

    assert_equal("/some/thing/1", pointer.to_s)
  end

  def test_resolve_root
    pointer = JSONP3::JSONPointer.new("")
    data = { "some" => { "thing" => "else" } }

    assert_equal(data, pointer.resolve(data))
  end

  def test_missing_key
    pointer = JSONP3::JSONPointer.new("/some/other")
    data = { "some" => { "thing" => "else" } }

    assert_equal(JSONP3::JSONPointer::UNDEFINED, pointer.resolve(data))
  end

  def test_index_out_of_range
    pointer = JSONP3::JSONPointer.new("/some/thing/7")
    data = { "some" => { "thing" => [1, 2, 3] } }

    assert_equal(JSONP3::JSONPointer::UNDEFINED, pointer.resolve(data))
  end

  def test_property_of_array
    pointer = JSONP3::JSONPointer.new("/some/thing/else")
    data = { "some" => { "thing" => [1, 2, 3] } }

    assert_equal(JSONP3::JSONPointer::UNDEFINED, pointer.resolve(data))
  end

  def test_index_of_hash
    pointer = JSONP3::JSONPointer.new("/some/thing/7")
    data = { "some" => { "thing" => { "else" => 42 } } }

    assert_equal(JSONP3::JSONPointer::UNDEFINED, pointer.resolve(data))
  end

  def test_index_of_string
    pointer = JSONP3::JSONPointer.new("/some/thing/7")
    data = { "some" => { "thing" => "else" } }

    assert_equal(JSONP3::JSONPointer::UNDEFINED, pointer.resolve(data))
  end

  def test_property_of_string
    pointer = JSONP3::JSONPointer.new("/some/thing/else")
    data = { "some" => { "thing" => "foo" } }

    assert_equal(JSONP3::JSONPointer::UNDEFINED, pointer.resolve(data))
  end

  def test_resolve_with_default
    pointer = JSONP3::JSONPointer.new("/some/other")
    data = { "some" => { "thing" => "else" } }

    assert_nil(pointer.resolve(data, default: nil))
    assert_equal(42, pointer.resolve(data, default: 42))
  end

  def test_no_leading_slash
    assert_raises(JSONP3::JSONPointerSyntaxError) { JSONP3::JSONPointer.new("some/other") }
  end

  def test_convenience_resolve
    assert_equal(42, JSONP3.resolve("/some/thing", { "some" => { "thing" => 42 } }))
  end

  def test_convenience_resolve_with_default
    assert_equal(7, JSONP3.resolve("/some/other", { "some" => { "thing" => 42 } }, default: 7))
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

    assert_equal(JSONP3::JSONPointer::UNDEFINED, pointer.resolve(data))
  end

  def test_resolve_with_parent
    pointer = JSONP3::JSONPointer.new("/some/thing")
    data = { "some" => { "thing" => [1, 2, 3] } }
    parent, item = pointer.resolve_with_parent(data)

    assert_equal(data["some"], parent)
    assert_equal(data["some"]["thing"], item)
  end

  def test_resolve_root_with_parent
    pointer = JSONP3::JSONPointer.new("")
    data = { "some" => { "thing" => [1, 2, 3] } }
    parent, item = pointer.resolve_with_parent(data)

    assert_equal(JSONP3::JSONPointer::UNDEFINED, parent)
    assert_equal(data, item)
  end

  def test_resolve_missing_with_parent
    pointer = JSONP3::JSONPointer.new("/some/other")
    data = { "some" => { "thing" => [1, 2, 3] } }
    parent, item = pointer.resolve_with_parent(data)

    assert_equal(data["some"], parent)
    assert_equal(JSONP3::JSONPointer::UNDEFINED, item)
  end

  def test_resolve_type_error_with_parent
    pointer = JSONP3::JSONPointer.new("/some/thing/1")
    data = { "some" => { "thing" => "else" } }
    parent, item = pointer.resolve_with_parent(data)

    assert_equal(data["some"]["thing"], parent)
    assert_equal(JSONP3::JSONPointer::UNDEFINED, item)
  end

  def test_join_with_nothing
    pointer = JSONP3::JSONPointer.new("/foo")

    assert_equal("/foo", pointer.join.to_s)
  end

  def test_join_with_single_part_single_token
    pointer = JSONP3::JSONPointer.new("/foo")

    assert_equal("/foo/bar", pointer.join("bar").to_s)
  end

  def test_join_with_single_part_multiple_tokens
    pointer = JSONP3::JSONPointer.new("/foo")

    assert_equal("/foo/bar/baz", pointer.join("bar/baz").to_s)
  end

  def test_join_with_multiple_parts
    pointer = JSONP3::JSONPointer.new("/foo")

    assert_equal("/foo/bar/baz", pointer.join("bar", "baz").to_s)
  end

  def test_join_with_multiple_parts_numeric_token
    pointer = JSONP3::JSONPointer.new("/foo")

    assert_equal("/foo/bar/baz/0", pointer.join("bar", "baz", "0").to_s)
  end

  def test_join_with_rooted_part
    pointer = JSONP3::JSONPointer.new("/foo")

    assert_equal("/bar", pointer.join("/bar").to_s)
  end

  def test_join_continue_after_rooted_part
    pointer = JSONP3::JSONPointer.new("/foo")

    assert_equal("/bar/0", pointer.join("/bar", "0").to_s)
  end

  def test_parent_of_pointer
    data = { "some" => { "thing" => [1, 2, 3] } }
    pointer = JSONP3::JSONPointer.new("/some/thing/0")
    parent = pointer.parent

    assert_equal(1, pointer.resolve(data))
    assert_equal("/some/thing", parent.to_s)
    assert_equal([1, 2, 3], parent.resolve(data))
  end

  def test_parent_of_parent
    data = { "some" => { "thing" => [1, 2, 3] } }
    pointer = JSONP3::JSONPointer.new("/some/thing/0")
    parent = pointer.parent
    grandparent = parent.parent

    assert_equal(1, pointer.resolve(data))
    assert_equal("/some/thing", parent.to_s)
    assert_equal([1, 2, 3], parent.resolve(data))
    assert_equal("/some", grandparent.to_s)
    assert_equal({ "thing" => [1, 2, 3] }, grandparent.resolve(data))
  end

  def test_parent_is_root
    data = { "some" => { "thing" => [1, 2, 3] } }
    pointer = JSONP3::JSONPointer.new("/some")
    parent = pointer.parent

    assert_equal(data["some"], pointer.resolve(data))
    assert_equal("", parent.to_s)
    assert_equal(data, parent.resolve(data))
  end

  def test_parent_of_root
    data = { "some" => { "thing" => [1, 2, 3] } }
    pointer = JSONP3::JSONPointer.new("")
    parent = pointer.parent

    assert_equal("", parent.to_s)
    assert_equal(data, parent.resolve(data))
  end

  def test_pointer_exists_truthy_value
    data = { "some" => { "thing" => [1, 2, 3] }, "other" => nil }
    pointer = JSONP3::JSONPointer.new("/some/thing")

    assert(pointer.exist?(data))
  end

  def test_pointer_exists_falsy_value
    data = { "some" => { "thing" => [1, 2, 3] }, "other" => nil }
    pointer = JSONP3::JSONPointer.new("/other")

    assert(pointer.exist?(data))
  end

  def test_pointer_does_not_exist
    data = { "some" => { "thing" => [1, 2, 3] }, "other" => nil }
    pointer = JSONP3::JSONPointer.new("/nosuchthing")

    refute(pointer.exist?(data))
  end
end
