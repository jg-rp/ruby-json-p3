# frozen_string_literal: true

require "test_helper"

class SymbolSelectorEnvironment < JSONPathRFC9535::JSONPathEnvironment
  NAME_SELECTOR = JSONPathRFC9535::SymbolNameSelector
end

SomeStruct = Struct.new("SomeStruct", :x)

class TestNameSelectors < Minitest::Test
  def test_standard_name_selector
    path = JSONPathRFC9535.compile("$.a")

    assert_equal(["b"], path.find({ "a" => "b", a: "c" }).map(&:value))
    assert_empty(path.find({ a: "c" }).map(&:value))
  end

  def test_symbol_name_selector
    env = SymbolSelectorEnvironment.new
    path = env.compile("$.a")

    # Strings take priority over symbols
    assert_equal(["b"], path.find({ a: "c", "a" => "b" }).map(&:value))
    assert_equal(["c"], path.find({ a: "c" }).map(&:value))
  end
end
