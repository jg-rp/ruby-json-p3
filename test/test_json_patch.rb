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

  # TODO: more tests
end
