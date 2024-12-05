# frozen_string_literal: true

require "test_helper"

class TestJSONPatch < Minitest::Test
  make_my_diffs_pretty!

  def test_remove_root
    patch = JSONP3::JSONPatch.new.remove("")
    error = assert_raises(JSONP3::JSONPatchError) { patch.apply({ "foo" => "bar" }) }
    assert_equal("can't remove root (remove:0)", error.message)
  end

  def test_test_op_fail
    patch = JSONP3::JSONPatch.new.test("/baz", "bar")
    error = assert_raises(JSONP3::JSONPatchError) { patch.apply({ "baz" => "qux" }) }
    assert_equal("test failed (test:0)", error.message)
  end

  def test_add_to_missing_target
    patch = JSONP3::JSONPatch.new.add("/baz/bat", "qux")

    error = assert_raises(JSONP3::JSONPatchError) { patch.apply({ "foo" => "bar" }) }
    assert_equal("no such property or item '/baz' (add:0)", error.message)
  end

  def test_move_to_child
    patch = JSONP3::JSONPatch.new.move("/foo/bar", "/foo/bar/baz")

    error = assert_raises(JSONP3::JSONPatchError) { patch.apply({ "foo" => { "bar" => { "baz" => [1, 2, 3] } } }) }
    assert_equal("can't move object to one of its children (move:0)", error.message)
  end

  def test_array_index_out_of_range
    patch = JSONP3::JSONPatch.new.add("/foo/7", 99)

    error = assert_raises(JSONP3::JSONPatchError) { patch.apply({ "foo" => [1, 2, 3] }) }
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

    patch = JSONP3::JSONPatch.new(patch_obj)

    assert_equal(patch_obj, patch.to_a)
  end

  def test_remove_missing_array_item
    patch = JSONP3::JSONPatch.new.remove("/foo/99")

    error = assert_raises(JSONP3::JSONPatchError) { patch.apply({ "foo" => [1, 2, 3] }) }
    assert_equal("no item to remove (remove:0)", error.message)
  end

  def test_remove_missing_hash_property
    patch = JSONP3::JSONPatch.new.remove("/foo/baz")

    error = assert_raises(JSONP3::JSONPatchError) { patch.apply({ "foo" => { "bar" => [1, 2, 3] } }) }
    assert_equal("no property to remove (remove:0)", error.message)
  end

  def test_replace_missing_array_item
    patch = JSONP3::JSONPatch.new.replace("/foo/99", 42)

    error = assert_raises(JSONP3::JSONPatchError) { patch.apply({ "foo" => [1, 2, 3] }) }
    assert_equal("no item to replace (replace:0)", error.message)
  end

  def test_replace_missing_hash_property
    patch = JSONP3::JSONPatch.new.replace("/foo/baz", 42)

    error = assert_raises(JSONP3::JSONPatchError) { patch.apply({ "foo" => { "bar" => [1, 2, 3] } }) }
    assert_equal("no property to replace (replace:0)", error.message)
  end

  def test_move_to_root
    patch = JSONP3::JSONPatch.new.move("/foo", "")

    assert_equal({ "bar" => [1, 2, 3] }, patch.apply({ "foo" => { "bar" => [1, 2, 3] } }))
  end

  def test_copy_to_root
    patch = JSONP3::JSONPatch.new.copy("/foo", "")
    data = { "foo" => { "bar" => [1, 2, 3] } }

    assert_equal({ "bar" => [1, 2, 3] }, patch.apply(data))
    assert_equal({ "foo" => { "bar" => [1, 2, 3] } }, data)
  end

  def test_build_missing_op
    op = { "path" => "", "value" => "foo" }
    error = assert_raises(JSONP3::JSONPatchError) { JSONP3::JSONPatch.new([op]) }
    assert_equal("expected 'op' to be one of 'add', 'remove', 'replace', 'move', 'copy' or 'test' (:0)",
                 error.message)
  end

  def test_build_missing_path
    op = { "op" => "add", "value" => "foo" }
    error = assert_raises(JSONP3::JSONPatchError) { JSONP3::JSONPatch.new([op]) }
    assert_equal("missing property 'path' (add:0)", error.message)
  end

  def test_build_missing_value
    op = { "op" => "add", "path" => "/foo" }
    error = assert_raises(JSONP3::JSONPatchError) { JSONP3::JSONPatch.new([op]) }
    assert_equal("missing property 'value' (add:0)", error.message)
  end

  def test_build_invalid_pointer
    op = { "op" => "add", "path" => "foo/", "value" => 42 }
    error = assert_raises(JSONP3::JSONPatchError) { JSONP3::JSONPatch.new([op]) }
    assert_equal("pointers must start with a slash or be the empty string (add:0)", error.message)
  end

  def test_move_to_end_of_array
    patch = JSONP3::JSONPatch.new.move("/a", "/foo/bar/-")
    data = { "foo" => { "bar" => [1, 2, 3] }, "a" => "b" }

    assert_equal({ "foo" => { "bar" => [1, 2, 3, "b"] } }, patch.apply(data))
  end

  def test_copy_to_end_of_array
    patch = JSONP3::JSONPatch.new.copy("/a", "/foo/bar/-")
    data = { "foo" => { "bar" => [1, 2, 3] }, "a" => "b" }

    assert_equal({ "foo" => { "bar" => [1, 2, 3, "b"] }, "a" => "b" }, patch.apply(data))
  end
end
