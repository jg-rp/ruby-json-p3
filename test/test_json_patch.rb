# frozen_string_literal: true

require "test_helper"

class TestJSONPatch < Minitest::Test
  make_my_diffs_pretty!

  def test_remove_root
    patch = JSONP3::Patch.new.remove("")
    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "foo" => "bar" }) }
    assert_equal("can't remove root (remove:0)", error.message)
  end

  def test_test_op_fail
    patch = JSONP3::Patch.new.test("/baz", "bar")
    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "baz" => "qux" }) }
    assert_equal("test failed (test:0)", error.message)
  end

  def test_add_to_missing_target
    patch = JSONP3::Patch.new.add("/baz/bat", "qux")

    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "foo" => "bar" }) }
    assert_equal("no such property or item '/baz' (add:0)", error.message)
  end

  def test_move_to_child
    patch = JSONP3::Patch.new.move("/foo/bar", "/foo/bar/baz")

    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "foo" => { "bar" => { "baz" => [1, 2, 3] } } }) }
    assert_equal("can't move object to one of its children (move:0)", error.message)
  end

  def test_array_index_out_of_range
    patch = JSONP3::Patch.new.add("/foo/7", 99)

    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "foo" => [1, 2, 3] }) }
    assert_equal("index out of range (add:0)", error.message)
  end

  def test_to_array
    patch_obj = [
      { "op" => "add", "path" => "/foo/bar", "value" => "foo" },
      { "op" => "remove", "path" => "/foo/bar" },
      { "op" => "replace", "path" => "/foo/bar", "value" => "foo" },
      { "op" => "move", "from" => "/baz/foo", "path" => "/foo/bar" },
      { "op" => "copy", "from" => "/baz/foo", "path" => "/foo/bar" },
      { "op" => "test", "path" => "/foo/bar", "value" => "foo" }
    ]

    patch = JSONP3::Patch.new(patch_obj)

    assert_equal(patch_obj, patch.to_a)
  end

  def test_remove_missing_array_item
    patch = JSONP3::Patch.new.remove("/foo/99")

    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "foo" => [1, 2, 3] }) }
    assert_equal("no item to remove (remove:0)", error.message)
  end

  def test_remove_missing_hash_property
    patch = JSONP3::Patch.new.remove("/foo/baz")

    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "foo" => { "bar" => [1, 2, 3] } }) }
    assert_equal("no property to remove (remove:0)", error.message)
  end

  def test_replace_missing_array_item
    patch = JSONP3::Patch.new.replace("/foo/99", 42)

    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "foo" => [1, 2, 3] }) }
    assert_equal("no item to replace (replace:0)", error.message)
  end

  def test_replace_missing_hash_property
    patch = JSONP3::Patch.new.replace("/foo/baz", 42)

    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "foo" => { "bar" => [1, 2, 3] } }) }
    assert_equal("no property to replace (replace:0)", error.message)
  end

  def test_move_to_root
    patch = JSONP3::Patch.new.move("/foo", "")

    assert_equal({ "bar" => [1, 2, 3] }, patch.apply!({ "foo" => { "bar" => [1, 2, 3] } }))
  end

  def test_copy_to_root
    patch = JSONP3::Patch.new.copy("/foo", "")
    data = { "foo" => { "bar" => [1, 2, 3] } }

    assert_equal({ "bar" => [1, 2, 3] }, patch.apply!(data))
    assert_equal({ "foo" => { "bar" => [1, 2, 3] } }, data)
  end

  def test_build_missing_op
    op = { "path" => "", "value" => "foo" }
    error = assert_raises(JSONP3::Patch::Error) { JSONP3::Patch.new([op]) }
    assert_equal("expected 'op' to be one of 'add', 'remove', 'replace', 'move', 'copy' or 'test' (:0)",
                 error.message)
  end

  def test_build_missing_path
    op = { "op" => "add", "value" => "foo" }
    error = assert_raises(JSONP3::Patch::Error) { JSONP3::Patch.new([op]) }
    assert_equal("missing property 'path' (add:0)", error.message)
  end

  def test_build_missing_value
    op = { "op" => "add", "path" => "/foo" }
    error = assert_raises(JSONP3::Patch::Error) { JSONP3::Patch.new([op]) }
    assert_equal("missing property 'value' (add:0)", error.message)
  end

  def test_build_invalid_pointer
    op = { "op" => "add", "path" => "foo/", "value" => 42 }
    error = assert_raises(JSONP3::Patch::Error) { JSONP3::Patch.new([op]) }
    assert_equal("pointers must start with a slash or be the empty string (add:0)", error.message)
  end

  def test_move_to_end_of_array
    patch = JSONP3::Patch.new.move("/a", "/foo/bar/-")
    data = { "foo" => { "bar" => [1, 2, 3] }, "a" => "b" }

    assert_equal({ "foo" => { "bar" => [1, 2, 3, "b"] } }, patch.apply!(data))
  end

  def test_copy_to_end_of_array
    patch = JSONP3::Patch.new.copy("/a", "/foo/bar/-")
    data = { "foo" => { "bar" => [1, 2, 3] }, "a" => "b" }

    assert_equal({ "foo" => { "bar" => [1, 2, 3, "b"] }, "a" => "b" }, patch.apply!(data))
  end

  def test_add_at_array_length
    patch = JSONP3::Patch.new.add("/foo/2", 3)

    assert_equal({ "foo" => [1, 2, 3] }, patch.apply!({ "foo" => [1, 2] }))
  end

  def test_add_to_empty_array
    patch = JSONP3::Patch.new.add("/foo/0", 1)

    assert_equal({ "foo" => [1] }, patch.apply!({ "foo" => [] }))
  end

  def test_add_beyond_array_length
    patch = JSONP3::Patch.new.add("/foo/3", 3)
    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "foo" => [1, 2] }) }
    assert_equal("index out of range (add:0)", error.message)
  end

  def test_move_array_element_forward
    patch = JSONP3::Patch.new.move("/foo/0", "/foo/1")

    assert_equal({ "foo" => [2, 1, 3] }, patch.apply!({ "foo" => [1, 2, 3] }))
  end

  def test_move_array_element_backward
    patch = JSONP3::Patch.new.move("/foo/2", "/foo/0")

    assert_equal({ "foo" => [3, 1, 2] }, patch.apply!({ "foo" => [1, 2, 3] }))
  end

  def test_move_sequence_reorders_array
    patch = JSONP3::Patch.new.move("/foo/0", "/foo/1").move("/foo/0", "/foo/2").move("/foo/1", "/foo/0")

    assert_equal({ "foo" => [3, 1, 2] }, patch.apply!({ "foo" => [1, 2, 3] }))
  end

  def test_move_into_another_array
    patch = JSONP3::Patch.new.move("/a", "/foo/1")

    assert_equal({ "foo" => [1, "b", 2] }, patch.apply!({ "foo" => [1, 2], "a" => "b" }))
  end

  def test_move_beyond_array_length
    patch = JSONP3::Patch.new.move("/a", "/foo/3")
    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "foo" => [1, 2], "a" => "b" }) }
    assert_equal("index out of range (move:0)", error.message)
  end

  def test_move_to_missing_parent
    patch = JSONP3::Patch.new.move("/a", "/nosuchthing/b")
    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "a" => 1 }) }
    assert_equal("no such property or item '/nosuchthing' (move:0)", error.message)
  end

  def test_move_to_scalar_parent
    patch = JSONP3::Patch.new.move("/a", "/s/b")
    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "a" => 1, "s" => "str" }) }
    assert_equal("unexpected operation on String (move:0)", error.message)
  end

  def test_copy_to_missing_parent
    patch = JSONP3::Patch.new.copy("/a", "/nosuchthing/b")
    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "a" => 1 }) }
    assert_equal("no such property or item '/nosuchthing' (copy:0)", error.message)
  end

  def test_copy_beyond_array_length
    patch = JSONP3::Patch.new.copy("/a", "/foo/3")
    error = assert_raises(JSONP3::Patch::Error) { patch.apply!({ "foo" => [1, 2], "a" => "b" }) }
    assert_equal("index out of range (copy:0)", error.message)
  end

  def test_copy_to_end_of_array_is_a_deep_copy
    patch = JSONP3::Patch.new.copy("/a", "/foo/-")
    data = patch.apply!({ "foo" => [], "a" => { "b" => 1 } })
    data["foo"][0]["b"] = 2

    assert_equal({ "b" => 1 }, data["a"])
  end

  def test_add_numeric_object_member
    patch = JSONP3::Patch.new.add("/foo/1", "new")

    assert_equal({ "foo" => { "1" => "new" } }, patch.apply!({ "foo" => { "1" => "old" } }))
  end

  def test_replace_numeric_object_member
    patch = JSONP3::Patch.new.replace("/foo/1", "new")

    assert_equal({ "foo" => { "1" => "new" } }, patch.apply!({ "foo" => { "1" => "old" } }))
  end

  def test_remove_numeric_object_member
    patch = JSONP3::Patch.new.remove("/foo/1")

    assert_equal({ "foo" => {} }, patch.apply!({ "foo" => { "1" => "old" } }))
  end

  def test_move_numeric_object_member
    patch = JSONP3::Patch.new.move("/foo/1", "/foo/2")

    assert_equal({ "foo" => { "2" => "old" } }, patch.apply!({ "foo" => { "1" => "old" } }))
  end

  def test_copy_to_numeric_object_member
    patch = JSONP3::Patch.new.copy("/a", "/foo/1")

    assert_equal({ "foo" => { "1" => "b" }, "a" => "b" }, patch.apply!({ "foo" => {}, "a" => "b" }))
  end
end
