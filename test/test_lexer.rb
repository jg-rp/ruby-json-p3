# frozen_string_literal: true

require "test_helper"

TEST_CASES = [
  {
    name: "basic shorthand name",
    query: "$.foo.bar",
    want: [
      [:token_dollar, "$"],
      [:token_dot, "."],
      [:token_name, "foo"],
      [:token_dot, "."],
      [:token_name, "bar"]
    ]
  },
  {
    name: "bracketed name",
    query: "$['foo']['bar']",
    want: [
      [:token_dollar, "$"],
      [:token_lbracket, "["],
      [:token_single_quoted_string, "foo"],
      [:token_rbracket, "]"],
      [:token_lbracket, "["],
      [:token_single_quoted_string, "bar"],
      [:token_rbracket, "]"]
    ]
  },
  {
    name: "basic index",
    query: "$.foo[1]",
    want: [
      [:token_dollar, "$"],
      [:token_dot, "."],
      [:token_name, "foo"],
      [:token_lbracket, "["],
      [:token_index, "1"],
      [:token_rbracket, "]"]
    ]
  },
  {
    name: "whitespace after root",
    query: "$ .foo.bar",
    want: [
      [:token_dollar, "$"],
      [:token_trivia, " "],
      [:token_dot, "."],
      [:token_name, "foo"],
      [:token_dot, "."],
      [:token_name, "bar"]
    ]
  }

  # TODO: more tests
].freeze

def tokenize(query)
  JSONP3::Path.tokenize(query).map do |token|
    [token.first, JSONP3::Path.get_token_value(token, query)]
  end
end

class TestLexer < Minitest::Spec
  make_my_diffs_pretty!

  describe "tokenize queries" do
    TEST_CASES.each do |test_case|
      it test_case[:name] do
        _(tokenize(test_case[:query])).must_equal test_case[:want]
      end
    end
  end
end
