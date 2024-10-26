# frozen_string_literal: true

require "test_helper"

Token = JSONP3::Token

TEST_CASES = [
  {
    name: "basic shorthand name",
    query: "$.foo.bar",
    want: [
      Token.new(:token_root, "$", 0, "$.foo.bar"),
      Token.new(:token_name, "foo", 2, "$.foo.bar"),
      Token.new(:token_name, "bar", 6, "$.foo.bar"),
      Token.new(:token_eoi, "", 9, "$.foo.bar")
    ]
  },
  {
    name: "bracketed name",
    query: "$['foo']['bar']",
    want: [
      Token.new(:token_root, "$", 0, "$['foo']['bar']"),
      Token.new(:token_lbracket, "[", 1, "$['foo']['bar']"),
      Token.new(:token_single_quote_string, "foo", 3, "$['foo']['bar']"),
      Token.new(:token_rbracket, "]", 7, "$['foo']['bar']"),
      Token.new(:token_lbracket, "[", 8, "$['foo']['bar']"),
      Token.new(:token_single_quote_string, "bar", 10, "$['foo']['bar']"),
      Token.new(:token_rbracket, "]", 14, "$['foo']['bar']"),
      Token.new(:token_eoi, "", 15, "$['foo']['bar']")
    ]
  },
  {
    name: "basic index",
    query: "$.foo[1]",
    want: [
      Token.new(:token_root, "$", 0, "$.foo[1]"),
      Token.new(:token_name, "foo", 2, "$.foo[1]"),
      Token.new(:token_lbracket, "[", 5, "$.foo[1]"),
      Token.new(:token_index, "1", 6, "$.foo[1]"),
      Token.new(:token_rbracket, "]", 7, "$.foo[1]"),
      Token.new(:token_eoi, "", 8, "$.foo[1]")
    ]
  },
  {
    name: "missing root selector",
    query: "foo.bar",
    want: [
      Token.new(:token_error, "f", 0, "foo.bar", message: "expected '$', found 'f'")
    ]
  },
  {
    name: "root property selector without dot",
    query: "$foo",
    want: [
      Token.new(:token_root, "$", 0, "$foo"),
      Token.new(
        :token_error,
        "f",
        1,
        "$foo",
        message: "expected '.', '..' or a bracketed selection, found 'f'"
      )
    ]
  },
  {
    name: "whitespace after root",
    query: "$ .foo.bar",
    want: [
      Token.new(:token_root, "$", 0, "$ .foo.bar"),
      Token.new(:token_name, "foo", 3, "$ .foo.bar"),
      Token.new(:token_name, "bar", 7, "$ .foo.bar"),
      Token.new(:token_eoi, "", 10, "$ .foo.bar")
    ]
  },
  {
    name: "whitespace before dot property",
    query: "$. foo.bar",
    want: [
      Token.new(:token_root, "$", 0, "$. foo.bar"),
      Token.new(:token_error, " ", 2, "$. foo.bar", message: "unexpected whitespace after dot")
    ]
  },
  {
    name: "whitespace after dot property",
    query: "$.foo .bar",
    want: [
      Token.new(:token_root, "$", 0, "$.foo .bar"),
      Token.new(:token_name, "foo", 2, "$.foo .bar"),
      Token.new(:token_name, "bar", 7, "$.foo .bar"),
      Token.new(:token_eoi, "", 10, "$.foo .bar")
    ]
  },
  {
    name: "basic dot wild",
    query: "$.foo.*",
    want: [
      Token.new(:token_root, "$", 0, "$.foo.*"),
      Token.new(:token_name, "foo", 2, "$.foo.*"),
      Token.new(:token_wild, "*", 6, "$.foo.*"),
      Token.new(:token_eoi, "", 7, "$.foo.*")
    ]
  },
  {
    name: "basic recurse",
    query: "$..foo",
    want: [
      Token.new(:token_root, "$", 0, "$..foo"),
      Token.new(:token_double_dot, "..", 1, "$..foo"),
      Token.new(:token_name, "foo", 3, "$..foo"),
      Token.new(:token_eoi, "", 6, "$..foo")
    ]
  },
  {
    name: "basic recurse with trailing dot",
    query: "$...foo",
    want: [
      Token.new(:token_root, "$", 0, "$...foo"),
      Token.new(:token_double_dot, "..", 1, "$...foo"),
      Token.new(
        :token_error,
        ".",
        3,
        "$...foo",
        message: "unexpected descendant selection token '.'"
      )
    ]
  },
  {
    name: "erroneous double recurse",
    query: "$....foo",
    want: [
      Token.new(:token_root, "$", 0, "$....foo"),
      Token.new(:token_double_dot, "..", 1, "$....foo"),
      Token.new(
        :token_error,
        ".",
        3,
        "$....foo",
        message: "unexpected descendant selection token '.'"
      )
    ]
  },
  {
    name: "bracketed name selector, double quotes",
    query: '$.foo["bar"]',
    want: [
      Token.new(:token_root, "$", 0, '$.foo["bar"]'),
      Token.new(:token_name, "foo", 2, '$.foo["bar"]'),
      Token.new(:token_lbracket, "[", 5, '$.foo["bar"]'),
      Token.new(:token_double_quote_string, "bar", 7, '$.foo["bar"]'),
      Token.new(:token_rbracket, "]", 11, '$.foo["bar"]'),
      Token.new(:token_eoi, "", 12, '$.foo["bar"]')
    ]
  },
  {
    name: "bracketed name selector, single quotes",
    query: "$.foo['bar']",
    want: [
      Token.new(:token_root, "$", 0, "$.foo['bar']"),
      Token.new(:token_name, "foo", 2, "$.foo['bar']"),
      Token.new(:token_lbracket, "[", 5, "$.foo['bar']"),
      Token.new(:token_single_quote_string, "bar", 7, "$.foo['bar']"),
      Token.new(:token_rbracket, "]", 11, "$.foo['bar']"),
      Token.new(:token_eoi, "", 12, "$.foo['bar']")
    ]
  },
  {
    name: "multiple selectors",
    query: "$.foo['bar', 123, *]",
    want: [
      Token.new(:token_root, "$", 0, "$.foo['bar', 123, *]"),
      Token.new(:token_name, "foo", 2, "$.foo['bar', 123, *]"),
      Token.new(:token_lbracket, "[", 5, "$.foo['bar', 123, *]"),
      Token.new(:token_single_quote_string, "bar", 7, "$.foo['bar', 123, *]"),
      Token.new(:token_comma, ",", 11, "$.foo['bar', 123, *]"),
      Token.new(:token_index, "123", 13, "$.foo['bar', 123, *]"),
      Token.new(:token_comma, ",", 16, "$.foo['bar', 123, *]"),
      Token.new(:token_wild, "*", 18, "$.foo['bar', 123, *]"),
      Token.new(:token_rbracket, "]", 19, "$.foo['bar', 123, *]"),
      Token.new(:token_eoi, "", 20, "$.foo['bar', 123, *]")
    ]
  },
  {
    name: "slice",
    query: "$.foo[1:3]",
    want: [
      Token.new(:token_root, "$", 0, "$.foo[1:3]"),
      Token.new(:token_name, "foo", 2, "$.foo[1:3]"),
      Token.new(:token_lbracket, "[", 5, "$.foo[1:3]"),
      Token.new(:token_index, "1", 6, "$.foo[1:3]"),
      Token.new(:token_colon, ":", 7, "$.foo[1:3]"),
      Token.new(:token_index, "3", 8, "$.foo[1:3]"),
      Token.new(:token_rbracket, "]", 9, "$.foo[1:3]"),
      Token.new(:token_eoi, "", 10, "$.foo[1:3]")
    ]
  },
  {
    name: "filter",
    query: "$.foo[?@.bar]",
    want: [
      Token.new(:token_root, "$", 0, "$.foo[?@.bar]"),
      Token.new(:token_name, "foo", 2, "$.foo[?@.bar]"),
      Token.new(:token_lbracket, "[", 5, "$.foo[?@.bar]"),
      Token.new(:token_filter, "?", 6, "$.foo[?@.bar]"),
      Token.new(:token_current, "@", 7, "$.foo[?@.bar]"),
      Token.new(:token_name, "bar", 9, "$.foo[?@.bar]"),
      Token.new(:token_rbracket, "]", 12, "$.foo[?@.bar]"),
      Token.new(:token_eoi, "", 13, "$.foo[?@.bar]")
    ]
  },
  {
    name: "filter, parenthesized expression",
    query: "$.foo[?(@.bar)]",
    want: [
      Token.new(:token_root, "$", 0, "$.foo[?(@.bar)]"),
      Token.new(:token_name, "foo", 2, "$.foo[?(@.bar)]"),
      Token.new(:token_lbracket, "[", 5, "$.foo[?(@.bar)]"),
      Token.new(:token_filter, "?", 6, "$.foo[?(@.bar)]"),
      Token.new(:token_lparen, "(", 7, "$.foo[?(@.bar)]"),
      Token.new(:token_current, "@", 8, "$.foo[?(@.bar)]"),
      Token.new(:token_name, "bar", 10, "$.foo[?(@.bar)]"),
      Token.new(:token_rparen, ")", 13, "$.foo[?(@.bar)]"),
      Token.new(:token_rbracket, "]", 14, "$.foo[?(@.bar)]"),
      Token.new(:token_eoi, "", 15, "$.foo[?(@.bar)]")
    ]
  },
  {
    name: "two filters",
    query: "$.foo[?@.bar, ?@.baz]",
    want: [
      Token.new(:token_root, "$", 0, "$.foo[?@.bar, ?@.baz]"),
      Token.new(:token_name, "foo", 2, "$.foo[?@.bar, ?@.baz]"),
      Token.new(:token_lbracket, "[", 5, "$.foo[?@.bar, ?@.baz]"),
      Token.new(:token_filter, "?", 6, "$.foo[?@.bar, ?@.baz]"),
      Token.new(:token_current, "@", 7, "$.foo[?@.bar, ?@.baz]"),
      Token.new(:token_name, "bar", 9, "$.foo[?@.bar, ?@.baz]"),
      Token.new(:token_comma, ",", 12, "$.foo[?@.bar, ?@.baz]"),
      Token.new(:token_filter, "?", 14, "$.foo[?@.bar, ?@.baz]"),
      Token.new(:token_current, "@", 15, "$.foo[?@.bar, ?@.baz]"),
      Token.new(:token_name, "baz", 17, "$.foo[?@.bar, ?@.baz]"),
      Token.new(:token_rbracket, "]", 20, "$.foo[?@.bar, ?@.baz]"),
      Token.new(:token_eoi, "", 21, "$.foo[?@.bar, ?@.baz]")
    ]
  },
  {
    name: "filter, function",
    query: "$[?count(@.foo)>2]",
    want: [
      Token.new(:token_root, "$", 0, "$[?count(@.foo)>2]"),
      Token.new(:token_lbracket, "[", 1, "$[?count(@.foo)>2]"),
      Token.new(:token_filter, "?", 2, "$[?count(@.foo)>2]"),
      Token.new(:token_function, "count", 3, "$[?count(@.foo)>2]"),
      Token.new(:token_current, "@", 9, "$[?count(@.foo)>2]"),
      Token.new(:token_name, "foo", 11, "$[?count(@.foo)>2]"),
      Token.new(:token_rparen, ")", 14, "$[?count(@.foo)>2]"),
      Token.new(:token_gt, ">", 15, "$[?count(@.foo)>2]"),
      Token.new(:token_int, "2", 16, "$[?count(@.foo)>2]"),
      Token.new(:token_rbracket, "]", 17, "$[?count(@.foo)>2]"),
      Token.new(:token_eoi, "", 18, "$[?count(@.foo)>2]")
    ]
  },
  {
    name: "filter, function with two args",
    query: "$[?count(@.foo, 1)>2]",
    want: [
      Token.new(:token_root, "$", 0, "$[?count(@.foo, 1)>2]"),
      Token.new(:token_lbracket, "[", 1, "$[?count(@.foo, 1)>2]"),
      Token.new(:token_filter, "?", 2, "$[?count(@.foo, 1)>2]"),
      Token.new(:token_function, "count", 3, "$[?count(@.foo, 1)>2]"),
      Token.new(:token_current, "@", 9, "$[?count(@.foo, 1)>2]"),
      Token.new(:token_name, "foo", 11, "$[?count(@.foo, 1)>2]"),
      Token.new(:token_comma, ",", 14, "$[?count(@.foo, 1)>2]"),
      Token.new(:token_int, "1", 16, "$[?count(@.foo, 1)>2]"),
      Token.new(:token_rparen, ")", 17, "$[?count(@.foo, 1)>2]"),
      Token.new(:token_gt, ">", 18, "$[?count(@.foo, 1)>2]"),
      Token.new(:token_int, "2", 19, "$[?count(@.foo, 1)>2]"),
      Token.new(:token_rbracket, "]", 20, "$[?count(@.foo, 1)>2]"),
      Token.new(:token_eoi, "", 21, "$[?count(@.foo, 1)>2]")
    ]
  },
  {
    name: "filter, parenthesized function",
    query: "$[?(count(@.foo)>2)]",
    want: [
      Token.new(:token_root, "$", 0, "$[?(count(@.foo)>2)]"),
      Token.new(:token_lbracket, "[", 1, "$[?(count(@.foo)>2)]"),
      Token.new(:token_filter, "?", 2, "$[?(count(@.foo)>2)]"),
      Token.new(:token_lparen, "(", 3, "$[?(count(@.foo)>2)]"),
      Token.new(:token_function, "count", 4, "$[?(count(@.foo)>2)]"),
      Token.new(:token_current, "@", 10, "$[?(count(@.foo)>2)]"),
      Token.new(:token_name, "foo", 12, "$[?(count(@.foo)>2)]"),
      Token.new(:token_rparen, ")", 15, "$[?(count(@.foo)>2)]"),
      Token.new(:token_gt, ">", 16, "$[?(count(@.foo)>2)]"),
      Token.new(:token_int, "2", 17, "$[?(count(@.foo)>2)]"),
      Token.new(:token_rparen, ")", 18, "$[?(count(@.foo)>2)]"),
      Token.new(:token_rbracket, "]", 19, "$[?(count(@.foo)>2)]"),
      Token.new(:token_eoi, "", 20, "$[?(count(@.foo)>2)]")
    ]
  },
  {
    name: "filter, parenthesized function argument",
    query: "$[?(count((@.foo),1)>2)]",
    want: [
      Token.new(:token_root, "$", 0, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_lbracket, "[", 1, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_filter, "?", 2, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_lparen, "(", 3, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_function, "count", 4, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_lparen, "(", 10, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_current, "@", 11, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_name, "foo", 13, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_rparen, ")", 16, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_comma, ",", 17, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_int, "1", 18, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_rparen, ")", 19, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_gt, ">", 20, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_int, "2", 21, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_rparen, ")", 22, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_rbracket, "]", 23, "$[?(count((@.foo),1)>2)]"),
      Token.new(:token_eoi, "", 24, "$[?(count((@.foo),1)>2)]")
    ]
  },
  {
    name: "filter, nested",
    query: "$[?@[?@>1]]",
    want: [
      Token.new(:token_root, "$", 0, "$[?@[?@>1]]"),
      Token.new(:token_lbracket, "[", 1, "$[?@[?@>1]]"),
      Token.new(:token_filter, "?", 2, "$[?@[?@>1]]"),
      Token.new(:token_current, "@", 3, "$[?@[?@>1]]"),
      Token.new(:token_lbracket, "[", 4, "$[?@[?@>1]]"),
      Token.new(:token_filter, "?", 5, "$[?@[?@>1]]"),
      Token.new(:token_current, "@", 6, "$[?@[?@>1]]"),
      Token.new(:token_gt, ">", 7, "$[?@[?@>1]]"),
      Token.new(:token_int, "1", 8, "$[?@[?@>1]]"),
      Token.new(:token_rbracket, "]", 9, "$[?@[?@>1]]"),
      Token.new(:token_rbracket, "]", 10, "$[?@[?@>1]]"),
      Token.new(:token_eoi, "", 11, "$[?@[?@>1]]")
    ]
  },
  {
    name: "filter, nested brackets",
    query: "$[?@[?@[1]>1]]",
    want: [
      Token.new(:token_root, "$", 0, "$[?@[?@[1]>1]]"),
      Token.new(:token_lbracket, "[", 1, "$[?@[?@[1]>1]]"),
      Token.new(:token_filter, "?", 2, "$[?@[?@[1]>1]]"),
      Token.new(:token_current, "@", 3, "$[?@[?@[1]>1]]"),
      Token.new(:token_lbracket, "[", 4, "$[?@[?@[1]>1]]"),
      Token.new(:token_filter, "?", 5, "$[?@[?@[1]>1]]"),
      Token.new(:token_current, "@", 6, "$[?@[?@[1]>1]]"),
      Token.new(:token_lbracket, "[", 7, "$[?@[?@[1]>1]]"),
      Token.new(:token_index, "1", 8, "$[?@[?@[1]>1]]"),
      Token.new(:token_rbracket, "]", 9, "$[?@[?@[1]>1]]"),
      Token.new(:token_gt, ">", 10, "$[?@[?@[1]>1]]"),
      Token.new(:token_int, "1", 11, "$[?@[?@[1]>1]]"),
      Token.new(:token_rbracket, "]", 12, "$[?@[?@[1]>1]]"),
      Token.new(:token_rbracket, "]", 13, "$[?@[?@[1]>1]]"),
      Token.new(:token_eoi, "", 14, "$[?@[?@[1]>1]]")
    ]
  },
  {
    name: "function",
    query: "$[?foo()]",
    want: [
      Token.new(:token_root, "$", 0, "$[?foo()]"),
      Token.new(:token_lbracket, "[", 1, "$[?foo()]"),
      Token.new(:token_filter, "?", 2, "$[?foo()]"),
      Token.new(:token_function, "foo", 3, "$[?foo()]"),
      Token.new(:token_rparen, ")", 7, "$[?foo()]"),
      Token.new(:token_rbracket, "]", 8, "$[?foo()]"),
      Token.new(:token_eoi, "", 9, "$[?foo()]")
    ]
  },
  {
    name: "function, int literal",
    query: "$[?foo(42)]",
    want: [
      Token.new(:token_root, "$", 0, "$[?foo(42)]"),
      Token.new(:token_lbracket, "[", 1, "$[?foo(42)]"),
      Token.new(:token_filter, "?", 2, "$[?foo(42)]"),
      Token.new(:token_function, "foo", 3, "$[?foo(42)]"),
      Token.new(:token_int, "42", 7, "$[?foo(42)]"),
      Token.new(:token_rparen, ")", 9, "$[?foo(42)]"),
      Token.new(:token_rbracket, "]", 10, "$[?foo(42)]"),
      Token.new(:token_eoi, "", 11, "$[?foo(42)]")
    ]
  },
  {
    name: "function, two int args",
    query: "$[?foo(42, -7)]",
    want: [
      Token.new(:token_root, "$", 0, "$[?foo(42, -7)]"),
      Token.new(:token_lbracket, "[", 1, "$[?foo(42, -7)]"),
      Token.new(:token_filter, "?", 2, "$[?foo(42, -7)]"),
      Token.new(:token_function, "foo", 3, "$[?foo(42, -7)]"),
      Token.new(:token_int, "42", 7, "$[?foo(42, -7)]"),
      Token.new(:token_comma, ",", 9, "$[?foo(42, -7)]"),
      Token.new(:token_int, "-7", 11, "$[?foo(42, -7)]"),
      Token.new(:token_rparen, ")", 13, "$[?foo(42, -7)]"),
      Token.new(:token_rbracket, "]", 14, "$[?foo(42, -7)]"),
      Token.new(:token_eoi, "", 15, "$[?foo(42, -7)]")
    ]
  },
  {
    name: "boolean literals",
    query: "$[?true==false]",
    want: [
      Token.new(:token_root, "$", 0, "$[?true==false]"),
      Token.new(:token_lbracket, "[", 1, "$[?true==false]"),
      Token.new(:token_filter, "?", 2, "$[?true==false]"),
      Token.new(:token_true, "true", 3, "$[?true==false]"),
      Token.new(:token_eq, "==", 7, "$[?true==false]"),
      Token.new(:token_false, "false", 9, "$[?true==false]"),
      Token.new(:token_rbracket, "]", 14, "$[?true==false]"),
      Token.new(:token_eoi, "", 15, "$[?true==false]")
    ]
  },
  {
    name: "logical and",
    query: "$[?true && false]",
    want: [
      Token.new(:token_root, "$", 0, "$[?true && false]"),
      Token.new(:token_lbracket, "[", 1, "$[?true && false]"),
      Token.new(:token_filter, "?", 2, "$[?true && false]"),
      Token.new(:token_true, "true", 3, "$[?true && false]"),
      Token.new(:token_and, "&&", 8, "$[?true && false]"),
      Token.new(:token_false, "false", 11, "$[?true && false]"),
      Token.new(:token_rbracket, "]", 16, "$[?true && false]"),
      Token.new(:token_eoi, "", 17, "$[?true && false]")
    ]
  },
  {
    name: "float",
    query: "$[?@.foo > 42.7]",
    want: [
      Token.new(:token_root, "$", 0, "$[?@.foo > 42.7]"),
      Token.new(:token_lbracket, "[", 1, "$[?@.foo > 42.7]"),
      Token.new(:token_filter, "?", 2, "$[?@.foo > 42.7]"),
      Token.new(:token_current, "@", 3, "$[?@.foo > 42.7]"),
      Token.new(:token_name, "foo", 5, "$[?@.foo > 42.7]"),
      Token.new(:token_gt, ">", 9, "$[?@.foo > 42.7]"),
      Token.new(:token_float, "42.7", 11, "$[?@.foo > 42.7]"),
      Token.new(:token_rbracket, "]", 15, "$[?@.foo > 42.7]"),
      Token.new(:token_eoi, "", 16, "$[?@.foo > 42.7]")
    ]
  },
  {
    name: "trailing dot",
    query: "$.foo.",
    want: [
      Token.new(:token_root, "$", 0, "$.foo."),
      Token.new(:token_name, "foo", 2, "$.foo."),
      Token.new(:token_error, ".", 5, "$.foo.", message: "unexpected trailing dot")
    ]
  },
  {
    name: "unknown shorthand selector",
    query: "$.foo.&",
    want: [
      Token.new(:token_root, "$", 0, "$.foo.&"),
      Token.new(:token_name, "foo", 2, "$.foo.&"),
      Token.new(:token_error, "&", 6, "$.foo.&", message: "unexpected shorthand selector '&'")
    ]
  }
].freeze

class TestLexer < Minitest::Spec
  make_my_diffs_pretty!

  describe "tokenize queries" do
    TEST_CASES.each do |test_case|
      it test_case[:name] do
        lexer = JSONP3::Lexer.new(test_case[:query])
        lexer.run
        _(lexer.tokens).must_equal test_case[:want]
      end
    end
  end
end
