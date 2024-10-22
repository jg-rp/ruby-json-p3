# frozen_string_literal: true

require "test_helper"

Token = JSONPathRFC9535::Token

TEST_CASES = [
  {
    name: "basic shorthand name",
    query: "$.foo.bar",
    want: [
      Token.new(Token::ROOT, "$", 0, "$.foo.bar"),
      Token.new(Token::NAME, "foo", 2, "$.foo.bar"),
      Token.new(Token::NAME, "bar", 6, "$.foo.bar"),
      Token.new(Token::EOI, "", 9, "$.foo.bar")
    ]
  },
  {
    name: "bracketed name",
    query: "$['foo']['bar']",
    want: [
      Token.new(Token::ROOT, "$", 0, "$['foo']['bar']"),
      Token.new(Token::LBRACKET, "[", 1, "$['foo']['bar']"),
      Token.new(Token::SINGLE_QUOTE_STRING, "foo", 3, "$['foo']['bar']"),
      Token.new(Token::RBRACKET, "]", 7, "$['foo']['bar']"),
      Token.new(Token::LBRACKET, "[", 8, "$['foo']['bar']"),
      Token.new(Token::SINGLE_QUOTE_STRING, "bar", 10, "$['foo']['bar']"),
      Token.new(Token::RBRACKET, "]", 14, "$['foo']['bar']"),
      Token.new(Token::EOI, "", 15, "$['foo']['bar']")
    ]
  },
  {
    name: "basic index",
    query: "$.foo[1]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$.foo[1]"),
      Token.new(Token::NAME, "foo", 2, "$.foo[1]"),
      Token.new(Token::LBRACKET, "[", 5, "$.foo[1]"),
      Token.new(Token::INDEX, "1", 6, "$.foo[1]"),
      Token.new(Token::RBRACKET, "]", 7, "$.foo[1]"),
      Token.new(Token::EOI, "", 8, "$.foo[1]")
    ]
  },
  {
    name: "missing root selector",
    query: "foo.bar",
    want: [
      Token.new(Token::ERROR, "f", 0, "foo.bar", message: "expected '$', found 'f'")
    ]
  },
  {
    name: "root property selector without dot",
    query: "$foo",
    want: [
      Token.new(Token::ROOT, "$", 0, "$foo"),
      Token.new(
        Token::ERROR,
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
      Token.new(Token::ROOT, "$", 0, "$ .foo.bar"),
      Token.new(Token::NAME, "foo", 3, "$ .foo.bar"),
      Token.new(Token::NAME, "bar", 7, "$ .foo.bar"),
      Token.new(Token::EOI, "", 10, "$ .foo.bar")
    ]
  },
  {
    name: "whitespace before dot property",
    query: "$. foo.bar",
    want: [
      Token.new(Token::ROOT, "$", 0, "$. foo.bar"),
      Token.new(Token::ERROR, " ", 2, "$. foo.bar", message: "unexpected whitespace after dot")
    ]
  },
  {
    name: "whitespace after dot property",
    query: "$.foo .bar",
    want: [
      Token.new(Token::ROOT, "$", 0, "$.foo .bar"),
      Token.new(Token::NAME, "foo", 2, "$.foo .bar"),
      Token.new(Token::NAME, "bar", 7, "$.foo .bar"),
      Token.new(Token::EOI, "", 10, "$.foo .bar")
    ]
  },
  {
    name: "basic dot wild",
    query: "$.foo.*",
    want: [
      Token.new(Token::ROOT, "$", 0, "$.foo.*"),
      Token.new(Token::NAME, "foo", 2, "$.foo.*"),
      Token.new(Token::WILD, "*", 6, "$.foo.*"),
      Token.new(Token::EOI, "", 7, "$.foo.*")
    ]
  },
  {
    name: "basic recurse",
    query: "$..foo",
    want: [
      Token.new(Token::ROOT, "$", 0, "$..foo"),
      Token.new(Token::DOUBLE_DOT, "..", 1, "$..foo"),
      Token.new(Token::NAME, "foo", 3, "$..foo"),
      Token.new(Token::EOI, "", 6, "$..foo")
    ]
  },
  {
    name: "basic recurse with trailing dot",
    query: "$...foo",
    want: [
      Token.new(Token::ROOT, "$", 0, "$...foo"),
      Token.new(Token::DOUBLE_DOT, "..", 1, "$...foo"),
      Token.new(
        Token::ERROR,
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
      Token.new(Token::ROOT, "$", 0, "$....foo"),
      Token.new(Token::DOUBLE_DOT, "..", 1, "$....foo"),
      Token.new(
        Token::ERROR,
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
      Token.new(Token::ROOT, "$", 0, '$.foo["bar"]'),
      Token.new(Token::NAME, "foo", 2, '$.foo["bar"]'),
      Token.new(Token::LBRACKET, "[", 5, '$.foo["bar"]'),
      Token.new(Token::DOUBLE_QUOTE_STRING, "bar", 7, '$.foo["bar"]'),
      Token.new(Token::RBRACKET, "]", 11, '$.foo["bar"]'),
      Token.new(Token::EOI, "", 12, '$.foo["bar"]')
    ]
  },
  {
    name: "bracketed name selector, single quotes",
    query: "$.foo['bar']",
    want: [
      Token.new(Token::ROOT, "$", 0, "$.foo['bar']"),
      Token.new(Token::NAME, "foo", 2, "$.foo['bar']"),
      Token.new(Token::LBRACKET, "[", 5, "$.foo['bar']"),
      Token.new(Token::SINGLE_QUOTE_STRING, "bar", 7, "$.foo['bar']"),
      Token.new(Token::RBRACKET, "]", 11, "$.foo['bar']"),
      Token.new(Token::EOI, "", 12, "$.foo['bar']")
    ]
  },
  {
    name: "multiple selectors",
    query: "$.foo['bar', 123, *]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$.foo['bar', 123, *]"),
      Token.new(Token::NAME, "foo", 2, "$.foo['bar', 123, *]"),
      Token.new(Token::LBRACKET, "[", 5, "$.foo['bar', 123, *]"),
      Token.new(Token::SINGLE_QUOTE_STRING, "bar", 7, "$.foo['bar', 123, *]"),
      Token.new(Token::COMMA, ",", 11, "$.foo['bar', 123, *]"),
      Token.new(Token::INDEX, "123", 13, "$.foo['bar', 123, *]"),
      Token.new(Token::COMMA, ",", 16, "$.foo['bar', 123, *]"),
      Token.new(Token::WILD, "*", 18, "$.foo['bar', 123, *]"),
      Token.new(Token::RBRACKET, "]", 19, "$.foo['bar', 123, *]"),
      Token.new(Token::EOI, "", 20, "$.foo['bar', 123, *]")
    ]
  },
  {
    name: "slice",
    query: "$.foo[1:3]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$.foo[1:3]"),
      Token.new(Token::NAME, "foo", 2, "$.foo[1:3]"),
      Token.new(Token::LBRACKET, "[", 5, "$.foo[1:3]"),
      Token.new(Token::INDEX, "1", 6, "$.foo[1:3]"),
      Token.new(Token::COLON, ":", 7, "$.foo[1:3]"),
      Token.new(Token::INDEX, "3", 8, "$.foo[1:3]"),
      Token.new(Token::RBRACKET, "]", 9, "$.foo[1:3]"),
      Token.new(Token::EOI, "", 10, "$.foo[1:3]")
    ]
  },
  {
    name: "filter",
    query: "$.foo[?@.bar]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$.foo[?@.bar]"),
      Token.new(Token::NAME, "foo", 2, "$.foo[?@.bar]"),
      Token.new(Token::LBRACKET, "[", 5, "$.foo[?@.bar]"),
      Token.new(Token::FILTER, "?", 6, "$.foo[?@.bar]"),
      Token.new(Token::CURRENT, "@", 7, "$.foo[?@.bar]"),
      Token.new(Token::NAME, "bar", 9, "$.foo[?@.bar]"),
      Token.new(Token::RBRACKET, "]", 12, "$.foo[?@.bar]"),
      Token.new(Token::EOI, "", 13, "$.foo[?@.bar]")
    ]
  },
  {
    name: "filter, parenthesized expression",
    query: "$.foo[?(@.bar)]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$.foo[?(@.bar)]"),
      Token.new(Token::NAME, "foo", 2, "$.foo[?(@.bar)]"),
      Token.new(Token::LBRACKET, "[", 5, "$.foo[?(@.bar)]"),
      Token.new(Token::FILTER, "?", 6, "$.foo[?(@.bar)]"),
      Token.new(Token::LPAREN, "(", 7, "$.foo[?(@.bar)]"),
      Token.new(Token::CURRENT, "@", 8, "$.foo[?(@.bar)]"),
      Token.new(Token::NAME, "bar", 10, "$.foo[?(@.bar)]"),
      Token.new(Token::RPAREN, ")", 13, "$.foo[?(@.bar)]"),
      Token.new(Token::RBRACKET, "]", 14, "$.foo[?(@.bar)]"),
      Token.new(Token::EOI, "", 15, "$.foo[?(@.bar)]")
    ]
  },
  {
    name: "two filters",
    query: "$.foo[?@.bar, ?@.baz]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::NAME, "foo", 2, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::LBRACKET, "[", 5, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::FILTER, "?", 6, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::CURRENT, "@", 7, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::NAME, "bar", 9, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::COMMA, ",", 12, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::FILTER, "?", 14, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::CURRENT, "@", 15, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::NAME, "baz", 17, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::RBRACKET, "]", 20, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::EOI, "", 21, "$.foo[?@.bar, ?@.baz]")
    ]
  },
  {
    name: "filter, function",
    query: "$[?count(@.foo)>2]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$[?count(@.foo)>2]"),
      Token.new(Token::LBRACKET, "[", 1, "$[?count(@.foo)>2]"),
      Token.new(Token::FILTER, "?", 2, "$[?count(@.foo)>2]"),
      Token.new(Token::FUNCTION, "count", 3, "$[?count(@.foo)>2]"),
      Token.new(Token::CURRENT, "@", 9, "$[?count(@.foo)>2]"),
      Token.new(Token::NAME, "foo", 11, "$[?count(@.foo)>2]"),
      Token.new(Token::RPAREN, ")", 14, "$[?count(@.foo)>2]"),
      Token.new(Token::GT, ">", 15, "$[?count(@.foo)>2]"),
      Token.new(Token::INT, "2", 16, "$[?count(@.foo)>2]"),
      Token.new(Token::RBRACKET, "]", 17, "$[?count(@.foo)>2]"),
      Token.new(Token::EOI, "", 18, "$[?count(@.foo)>2]")
    ]
  },
  {
    name: "filter, function with two args",
    query: "$[?count(@.foo, 1)>2]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::LBRACKET, "[", 1, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::FILTER, "?", 2, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::FUNCTION, "count", 3, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::CURRENT, "@", 9, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::NAME, "foo", 11, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::COMMA, ",", 14, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::INT, "1", 16, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::RPAREN, ")", 17, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::GT, ">", 18, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::INT, "2", 19, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::RBRACKET, "]", 20, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::EOI, "", 21, "$[?count(@.foo, 1)>2]")
    ]
  },
  {
    name: "filter, parenthesized function",
    query: "$[?(count(@.foo)>2)]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$[?(count(@.foo)>2)]"),
      Token.new(Token::LBRACKET, "[", 1, "$[?(count(@.foo)>2)]"),
      Token.new(Token::FILTER, "?", 2, "$[?(count(@.foo)>2)]"),
      Token.new(Token::LPAREN, "(", 3, "$[?(count(@.foo)>2)]"),
      Token.new(Token::FUNCTION, "count", 4, "$[?(count(@.foo)>2)]"),
      Token.new(Token::CURRENT, "@", 10, "$[?(count(@.foo)>2)]"),
      Token.new(Token::NAME, "foo", 12, "$[?(count(@.foo)>2)]"),
      Token.new(Token::RPAREN, ")", 15, "$[?(count(@.foo)>2)]"),
      Token.new(Token::GT, ">", 16, "$[?(count(@.foo)>2)]"),
      Token.new(Token::INT, "2", 17, "$[?(count(@.foo)>2)]"),
      Token.new(Token::RPAREN, ")", 18, "$[?(count(@.foo)>2)]"),
      Token.new(Token::RBRACKET, "]", 19, "$[?(count(@.foo)>2)]"),
      Token.new(Token::EOI, "", 20, "$[?(count(@.foo)>2)]")
    ]
  },
  {
    name: "filter, parenthesized function argument",
    query: "$[?(count((@.foo),1)>2)]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::LBRACKET, "[", 1, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::FILTER, "?", 2, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::LPAREN, "(", 3, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::FUNCTION, "count", 4, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::LPAREN, "(", 10, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::CURRENT, "@", 11, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::NAME, "foo", 13, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::RPAREN, ")", 16, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::COMMA, ",", 17, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::INT, "1", 18, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::RPAREN, ")", 19, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::GT, ">", 20, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::INT, "2", 21, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::RPAREN, ")", 22, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::RBRACKET, "]", 23, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::EOI, "", 24, "$[?(count((@.foo),1)>2)]")
    ]
  },
  {
    name: "filter, nested",
    query: "$[?@[?@>1]]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$[?@[?@>1]]"),
      Token.new(Token::LBRACKET, "[", 1, "$[?@[?@>1]]"),
      Token.new(Token::FILTER, "?", 2, "$[?@[?@>1]]"),
      Token.new(Token::CURRENT, "@", 3, "$[?@[?@>1]]"),
      Token.new(Token::LBRACKET, "[", 4, "$[?@[?@>1]]"),
      Token.new(Token::FILTER, "?", 5, "$[?@[?@>1]]"),
      Token.new(Token::CURRENT, "@", 6, "$[?@[?@>1]]"),
      Token.new(Token::GT, ">", 7, "$[?@[?@>1]]"),
      Token.new(Token::INT, "1", 8, "$[?@[?@>1]]"),
      Token.new(Token::RBRACKET, "]", 9, "$[?@[?@>1]]"),
      Token.new(Token::RBRACKET, "]", 10, "$[?@[?@>1]]"),
      Token.new(Token::EOI, "", 11, "$[?@[?@>1]]")
    ]
  },
  {
    name: "filter, nested brackets",
    query: "$[?@[?@[1]>1]]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$[?@[?@[1]>1]]"),
      Token.new(Token::LBRACKET, "[", 1, "$[?@[?@[1]>1]]"),
      Token.new(Token::FILTER, "?", 2, "$[?@[?@[1]>1]]"),
      Token.new(Token::CURRENT, "@", 3, "$[?@[?@[1]>1]]"),
      Token.new(Token::LBRACKET, "[", 4, "$[?@[?@[1]>1]]"),
      Token.new(Token::FILTER, "?", 5, "$[?@[?@[1]>1]]"),
      Token.new(Token::CURRENT, "@", 6, "$[?@[?@[1]>1]]"),
      Token.new(Token::LBRACKET, "[", 7, "$[?@[?@[1]>1]]"),
      Token.new(Token::INDEX, "1", 8, "$[?@[?@[1]>1]]"),
      Token.new(Token::RBRACKET, "]", 9, "$[?@[?@[1]>1]]"),
      Token.new(Token::GT, ">", 10, "$[?@[?@[1]>1]]"),
      Token.new(Token::INT, "1", 11, "$[?@[?@[1]>1]]"),
      Token.new(Token::RBRACKET, "]", 12, "$[?@[?@[1]>1]]"),
      Token.new(Token::RBRACKET, "]", 13, "$[?@[?@[1]>1]]"),
      Token.new(Token::EOI, "", 14, "$[?@[?@[1]>1]]")
    ]
  },
  {
    name: "function",
    query: "$[?foo()]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$[?foo()]"),
      Token.new(Token::LBRACKET, "[", 1, "$[?foo()]"),
      Token.new(Token::FILTER, "?", 2, "$[?foo()]"),
      Token.new(Token::FUNCTION, "foo", 3, "$[?foo()]"),
      Token.new(Token::RPAREN, ")", 7, "$[?foo()]"),
      Token.new(Token::RBRACKET, "]", 8, "$[?foo()]"),
      Token.new(Token::EOI, "", 9, "$[?foo()]")
    ]
  },
  {
    name: "function, int literal",
    query: "$[?foo(42)]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$[?foo(42)]"),
      Token.new(Token::LBRACKET, "[", 1, "$[?foo(42)]"),
      Token.new(Token::FILTER, "?", 2, "$[?foo(42)]"),
      Token.new(Token::FUNCTION, "foo", 3, "$[?foo(42)]"),
      Token.new(Token::INT, "42", 7, "$[?foo(42)]"),
      Token.new(Token::RPAREN, ")", 9, "$[?foo(42)]"),
      Token.new(Token::RBRACKET, "]", 10, "$[?foo(42)]"),
      Token.new(Token::EOI, "", 11, "$[?foo(42)]")
    ]
  },
  {
    name: "function, two int args",
    query: "$[?foo(42, -7)]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$[?foo(42, -7)]"),
      Token.new(Token::LBRACKET, "[", 1, "$[?foo(42, -7)]"),
      Token.new(Token::FILTER, "?", 2, "$[?foo(42, -7)]"),
      Token.new(Token::FUNCTION, "foo", 3, "$[?foo(42, -7)]"),
      Token.new(Token::INT, "42", 7, "$[?foo(42, -7)]"),
      Token.new(Token::COMMA, ",", 9, "$[?foo(42, -7)]"),
      Token.new(Token::INT, "-7", 11, "$[?foo(42, -7)]"),
      Token.new(Token::RPAREN, ")", 13, "$[?foo(42, -7)]"),
      Token.new(Token::RBRACKET, "]", 14, "$[?foo(42, -7)]"),
      Token.new(Token::EOI, "", 15, "$[?foo(42, -7)]")
    ]
  },
  {
    name: "boolean literals",
    query: "$[?true==false]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$[?true==false]"),
      Token.new(Token::LBRACKET, "[", 1, "$[?true==false]"),
      Token.new(Token::FILTER, "?", 2, "$[?true==false]"),
      Token.new(Token::TRUE, "true", 3, "$[?true==false]"),
      Token.new(Token::EQ, "==", 7, "$[?true==false]"),
      Token.new(Token::FALSE, "false", 9, "$[?true==false]"),
      Token.new(Token::RBRACKET, "]", 14, "$[?true==false]"),
      Token.new(Token::EOI, "", 15, "$[?true==false]")
    ]
  },
  {
    name: "logical and",
    query: "$[?true && false]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$[?true && false]"),
      Token.new(Token::LBRACKET, "[", 1, "$[?true && false]"),
      Token.new(Token::FILTER, "?", 2, "$[?true && false]"),
      Token.new(Token::TRUE, "true", 3, "$[?true && false]"),
      Token.new(Token::AND, "&&", 8, "$[?true && false]"),
      Token.new(Token::FALSE, "false", 11, "$[?true && false]"),
      Token.new(Token::RBRACKET, "]", 16, "$[?true && false]"),
      Token.new(Token::EOI, "", 17, "$[?true && false]")
    ]
  },
  {
    name: "float",
    query: "$[?@.foo > 42.7]",
    want: [
      Token.new(Token::ROOT, "$", 0, "$[?@.foo > 42.7]"),
      Token.new(Token::LBRACKET, "[", 1, "$[?@.foo > 42.7]"),
      Token.new(Token::FILTER, "?", 2, "$[?@.foo > 42.7]"),
      Token.new(Token::CURRENT, "@", 3, "$[?@.foo > 42.7]"),
      Token.new(Token::NAME, "foo", 5, "$[?@.foo > 42.7]"),
      Token.new(Token::GT, ">", 9, "$[?@.foo > 42.7]"),
      Token.new(Token::FLOAT, "42.7", 11, "$[?@.foo > 42.7]"),
      Token.new(Token::RBRACKET, "]", 15, "$[?@.foo > 42.7]"),
      Token.new(Token::EOI, "", 16, "$[?@.foo > 42.7]")
    ]
  },
  {
    name: "trailing dot",
    query: "$.foo.",
    want: [
      Token.new(Token::ROOT, "$", 0, "$.foo."),
      Token.new(Token::NAME, "foo", 2, "$.foo."),
      Token.new(Token::ERROR, ".", 5, "$.foo.", message: "unexpected trailing dot")
    ]
  },
  {
    name: "unknown shorthand selector",
    query: "$.foo.&",
    want: [
      Token.new(Token::ROOT, "$", 0, "$.foo.&"),
      Token.new(Token::NAME, "foo", 2, "$.foo.&"),
      Token.new(Token::ERROR, "&", 6, "$.foo.&", message: "unexpected shorthand selector '&'")
    ]
  }
].freeze

class TestLexer < Minitest::Spec
  make_my_diffs_pretty!

  describe "tokenize queries" do
    TEST_CASES.each do |test_case|
      it test_case[:name] do
        lexer = JSONPathRFC9535::Lexer.new(test_case[:query])
        lexer.run
        _(lexer.tokens).must_equal test_case[:want]
      end
    end
  end
end
