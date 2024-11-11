# frozen_string_literal: true

require "test_helper"

class TestRelativeJSONPointer < Minitest::Test
  DOC = {
    "foo" => %w[bar baz biz],
    "highly" => { "nested" => { "object" => true } }
  }.freeze

  def test_zero_origin
    rel = "0"
    p = JSONP3::JSONPointer.new("/foo/1")
    r = JSONP3::RelativeJSONPointer.new(rel)
    new_pointer = r.to(p)

    assert_equal("baz", new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_parent_origin_pointer_index
    rel = "1/0"
    p = JSONP3::JSONPointer.new("/foo/1")
    r = JSONP3::RelativeJSONPointer.new(rel)
    new_pointer = r.to(p)

    assert_equal("bar", new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_negative_index_manipulation
    rel = "0-1"
    p = JSONP3::JSONPointer.new("/foo/1")
    r = JSONP3::RelativeJSONPointer.new(rel)
    new_pointer = r.to(p)

    assert_equal("bar", new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_grandparent_origin_nested_pointer
    rel = "2/highly/nested/objects"
    p = JSONP3::JSONPointer.new("/foo/1")
    r = JSONP3::RelativeJSONPointer.new(rel)
    new_pointer = r.to(p)

    assert(new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  # TODO:
  # def test_zero_origin_index
  #   rel = "0#"
  #   p = JSONP3::JSONPointer.new("/foo/1")
  #   r = JSONP3::RelativeJSONPointer.new(rel)
  #   new_pointer = r.to(p)

  #   assert_equal(1, new_pointer.resolve(DOC))
  #   assert_equal(p.to(rel).to_s, new_pointer.to_s)
  #   assert_equal(r.to_s, rel)
  # end
end
