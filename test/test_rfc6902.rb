# frozen_string_literal: true

require "test_helper"

class TestRFC6902 < Minitest::Spec
  make_my_diffs_pretty!

  TEST_CASES = [
    {
      "description" => "add an object member",
      "data" => { "foo" => "bar" },
      "patch" => JSONP3::JSONPatch.new.add("/baz", "qux"),
      "op" => { "op" => "add", "path" => "/baz", "value" => "qux" },
      "want" => { "foo" => "bar", "baz" => "qux" }
    },
    {
      "description" => "add an array element",
      "data" => { "foo" => %w[bar baz] },
      "patch" => JSONP3::JSONPatch.new.add("/foo/1", "qux"),
      "op" => { "op" => "add", "path" => "/foo/1", "value" => "qux" },
      "want" => { "foo" => %w[bar qux baz] }
    },
    {
      "description" => "append to an array",
      "data" => { "foo" => %w[bar baz] },
      "patch" => JSONP3::JSONPatch.new.add("/foo/-", "qux"),
      "op" => { "op" => "add", "path" => "/foo/-", "value" => "qux" },
      "want" => { "foo" => %w[bar baz qux] }
    },
    {
      "description" => "add to the root",
      "data" => { "foo" => "bar" },
      "patch" => JSONP3::JSONPatch.new.add("", { "some" => "thing" }),
      "op" => { "op" => "add", "path" => "", "value" => { "some" => "thing" } },
      "want" => { "some" => "thing" }
    },
    {
      "description" => "remove an object member",
      "data" => { "baz" => "qux", "foo" => "bar" },
      "patch" => JSONP3::JSONPatch.new.remove("/baz"),
      "op" => { "op" => "remove", "path" => "/baz" },
      "want" => { "foo" => "bar" }
    },
    {
      "description" => "remove an array element",
      "data" => { "foo" => %w[bar qux baz] },
      "patch" => JSONP3::JSONPatch.new.remove("/foo/1"),
      "op" => { "op" => "remove", "path" => "/foo/1" },
      "want" => { "foo" => %w[bar baz] }
    },
    {
      "description" => "replace an object member",
      "data" => { "baz" => "qux", "foo" => "bar" },
      "patch" => JSONP3::JSONPatch.new.replace("/baz", "boo"),
      "op" => { "op" => "replace", "path" => "/baz", "value" => "boo" },
      "want" => { "baz" => "boo", "foo" => "bar" }
    },
    {
      "description" => "replace an array element",
      "data" => { "foo" => [1, 2, 3] },
      "patch" => JSONP3::JSONPatch.new.replace("/foo/0", 9),
      "op" => { "op" => "replace", "path" => "/foo/0", "value" => 9 },
      "want" => { "foo" => [9, 2, 3] }
    },
    {
      "description" => "move a value",
      "data" => { "foo" => { "bar" => "baz", "waldo" => "fred" }, "qux" => { "corge" => "grault" } },
      "patch" => JSONP3::JSONPatch.new.move("/foo/waldo", "/qux/thud"),
      "op" => { "op" => "move", "from" => "/foo/waldo", "path" => "/qux/thud" },
      "want" => { "foo" => { "bar" => "baz" }, "qux" => { "corge" => "grault", "thud" => "fred" } }
    },
    {
      "description" => "move an array element",
      "data" => { "foo" => %w[all grass cows eat] },
      "patch" => JSONP3::JSONPatch.new.move("/foo/1", "/foo/3"),
      "op" => { "op" => "move", "from" => "/foo/1", "path" => "/foo/3" },
      "want" => { "foo" => %w[all cows eat grass] }
    },
    {
      "description" => "copy a value",
      "data" => { "foo" => { "bar" => "baz", "waldo" => "fred" }, "qux" => { "corge" => "grault" } },
      "patch" => JSONP3::JSONPatch.new.copy("/foo/waldo", "/qux/thud"),
      "op" => { "op" => "copy", "from" => "/foo/waldo", "path" => "/qux/thud" },
      "want" => {
        "foo" => { "bar" => "baz", "waldo" => "fred" },
        "qux" => { "corge" => "grault", "thud" => "fred" }
      }
    },
    {
      "description" => "copy an array element",
      "data" => { "foo" => %w[all grass cows eat] },
      "patch" => JSONP3::JSONPatch.new.copy("/foo/1", "/foo/3"),
      "op" => { "op" => "copy", "path" => "/foo/3", "from" => "/foo/1" },
      "want" => { "foo" => %w[all grass cows grass eat] }
    },
    {
      "description" => "test a value",
      "data" => { "baz" => "qux", "foo" => ["a", 2, "c"] },
      "patch" => JSONP3::JSONPatch.new.test("/baz", "qux").test("/foo/1", 2),
      "op" => { "op" => "test", "path" => "/baz", "value" => "qux" },
      "want" => { "baz" => "qux", "foo" => ["a", 2, "c"] }
    },
    {
      "description" => "add a nested member object",
      "data" => { "foo" => "bar" },
      "patch" => JSONP3::JSONPatch.new.add("/child", { "grandchild" => {} }),
      "op" => { "op" => "add", "path" => "/child", "value" => { "grandchild" => {} } },
      "want" => { "foo" => "bar", "child" => { "grandchild" => {} } }
    },
    {
      "description" => "add an array value",
      "data" => { "foo" => ["bar"] },
      "patch" => JSONP3::JSONPatch.new.add("/foo/-", %w[abc def]),
      "op" => { "op" => "add", "path" => "/foo/-", "value" => %w[abc def] },
      "want" => { "foo" => ["bar", %w[abc def]] }
    }
  ].freeze

  def deep_copy(obj)
    Marshal.load(Marshal.dump(obj))
  end

  describe "RFC6902" do
    TEST_CASES.each do |test_case|
      it test_case["description"] do
        _(test_case["patch"].apply(deep_copy(test_case["data"]))).must_equal(test_case["want"])
        _(JSONP3::JSONPatch.new([test_case["op"]]).apply(deep_copy(test_case["data"]))).must_equal(test_case["want"])
      end
    end
  end
end
