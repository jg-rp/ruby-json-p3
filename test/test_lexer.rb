# frozen_string_literal: true

require "test_helper"

Token = JSONPathRFC9535::Token

TEST_CASES = [
  {
    name: "basic shorthand name",
    query: "$.foo.bar",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$.foo.bar"),
      Token.new(Token::NAME, "foo", 2, 5, "$.foo.bar"),
      Token.new(Token::NAME, "bar", 6, 9, "$.foo.bar"),
      Token.new(Token::EOI, "", 9, 9, "$.foo.bar")
    ]
  },
  {
    name: "bracketed name",
    query: "$['foo']['bar']",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$['foo']['bar']"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$['foo']['bar']"),
      Token.new(Token::SINGLE_QUOTE_STRING, "foo", 3, 6, "$['foo']['bar']"),
      Token.new(Token::RBRACKET, "]", 7, 8, "$['foo']['bar']"),
      Token.new(Token::LBRACKET, "[", 8, 9, "$['foo']['bar']"),
      Token.new(Token::SINGLE_QUOTE_STRING, "bar", 10, 13, "$['foo']['bar']"),
      Token.new(Token::RBRACKET, "]", 14, 15, "$['foo']['bar']"),
      Token.new(Token::EOI, "", 15, 15, "$['foo']['bar']")
    ]
  },
  {
    name: "basic index",
    query: "$.foo[1]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$.foo[1]"),
      Token.new(Token::NAME, "foo", 2, 5, "$.foo[1]"),
      Token.new(Token::LBRACKET, "[", 5, 6, "$.foo[1]"),
      Token.new(Token::INDEX, "1", 6, 7, "$.foo[1]"),
      Token.new(Token::RBRACKET, "]", 7, 8, "$.foo[1]"),
      Token.new(Token::EOI, "", 8, 8, "$.foo[1]")
    ]
  },
  {
    name: "missing root selector",
    query: "foo.bar",
    want: [
      Token.new(Token::ERROR, "expected '$', found 'f'", 0, 1, "foo.bar")
    ]
  },
  {
    name: "root property selector without dot",
    query: "$foo",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$foo"),
      Token.new(
        Token::ERROR,
        "expected '.', '..' or a bracketed selection, found 'f'",
        1, 2,
        "$foo"
      )
    ]
  },
  {
    name: "whitespace after root",
    query: "$ .foo.bar",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$ .foo.bar"),
      Token.new(Token::NAME, "foo", 3, 6, "$ .foo.bar"),
      Token.new(Token::NAME, "bar", 7, 10, "$ .foo.bar"),
      Token.new(Token::EOI, "", 10, 10, "$ .foo.bar")
    ]
  },
  {
    name: "whitespace before dot property",
    query: "$. foo.bar",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$. foo.bar"),
      Token.new(Token::ERROR, "unexpected whitespace after dot", 2, 3, "$. foo.bar")
    ]
  },
  {
    name: "whitespace after dot property",
    query: "$.foo .bar",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$.foo .bar"),
      Token.new(Token::NAME, "foo", 2, 5, "$.foo .bar"),
      Token.new(Token::NAME, "bar", 7, 10, "$.foo .bar"),
      Token.new(Token::EOI, "", 10, 10, "$.foo .bar")
    ]
  },
  {
    name: "basic dot wild",
    query: "$.foo.*",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$.foo.*"),
      Token.new(Token::NAME, "foo", 2, 5, "$.foo.*"),
      Token.new(Token::WILD, "*", 6, 7, "$.foo.*"),
      Token.new(Token::EOI, "", 7, 7, "$.foo.*")
    ]
  },
  {
    name: "basic recurse",
    query: "$..foo",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$..foo"),
      Token.new(Token::DOUBLE_DOT, "..", 1, 3, "$..foo"),
      Token.new(Token::NAME, "foo", 3, 6, "$..foo"),
      Token.new(Token::EOI, "", 6, 6, "$..foo")
    ]
  },
  {
    name: "basic recurse with trailing dot",
    query: "$...foo",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$...foo"),
      Token.new(Token::DOUBLE_DOT, "..", 1, 3, "$...foo"),
      Token.new(
        Token::ERROR,
        "unexpected descendant selection token '.'",
        3, 4,
        "$...foo"
      )
    ]
  },
  {
    name: "erroneous double recurse",
    query: "$....foo",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$....foo"),
      Token.new(Token::DOUBLE_DOT, "..", 1, 3, "$....foo"),
      Token.new(
        Token::ERROR,
        "unexpected descendant selection token '.'",
        3, 4,
        "$....foo"
      )
    ]
  },
  {
    name: "bracketed name selector, double quotes",
    query: '$.foo["bar"]',
    want: [
      Token.new(Token::ROOT, "$", 0, 1, '$.foo["bar"]'),
      Token.new(Token::NAME, "foo", 2, 5, '$.foo["bar"]'),
      Token.new(Token::LBRACKET, "[", 5, 6, '$.foo["bar"]'),
      Token.new(Token::DOUBLE_QUOTE_STRING, "bar", 7, 10, '$.foo["bar"]'),
      Token.new(Token::RBRACKET, "]", 11, 12, '$.foo["bar"]'),
      Token.new(Token::EOI, "", 12, 12, '$.foo["bar"]')
    ]
  },
  {
    name: "bracketed name selector, single quotes",
    query: "$.foo['bar']",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$.foo['bar']"),
      Token.new(Token::NAME, "foo", 2, 5, "$.foo['bar']"),
      Token.new(Token::LBRACKET, "[", 5, 6, "$.foo['bar']"),
      Token.new(Token::SINGLE_QUOTE_STRING, "bar", 7, 10, "$.foo['bar']"),
      Token.new(Token::RBRACKET, "]", 11, 12, "$.foo['bar']"),
      Token.new(Token::EOI, "", 12, 12, "$.foo['bar']")
    ]
  },
  {
    name: "multiple selectors",
    query: "$.foo['bar', 123, *]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$.foo['bar', 123, *]"),
      Token.new(Token::NAME, "foo", 2, 5, "$.foo['bar', 123, *]"),
      Token.new(Token::LBRACKET, "[", 5, 6, "$.foo['bar', 123, *]"),
      Token.new(Token::SINGLE_QUOTE_STRING, "bar", 7, 10, "$.foo['bar', 123, *]"),
      Token.new(Token::COMMA, ",", 11, 12, "$.foo['bar', 123, *]"),
      Token.new(Token::INDEX, "123", 13, 16, "$.foo['bar', 123, *]"),
      Token.new(Token::COMMA, ",", 16, 17, "$.foo['bar', 123, *]"),
      Token.new(Token::WILD, "*", 18, 19, "$.foo['bar', 123, *]"),
      Token.new(Token::RBRACKET, "]", 19, 20, "$.foo['bar', 123, *]"),
      Token.new(Token::EOI, "", 20, 20, "$.foo['bar', 123, *]")
    ]
  },
  {
    name: "slice",
    query: "$.foo[1:3]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$.foo[1:3]"),
      Token.new(Token::NAME, "foo", 2, 5, "$.foo[1:3]"),
      Token.new(Token::LBRACKET, "[", 5, 6, "$.foo[1:3]"),
      Token.new(Token::INDEX, "1", 6, 7, "$.foo[1:3]"),
      Token.new(Token::COLON, ":", 7, 8, "$.foo[1:3]"),
      Token.new(Token::INDEX, "3", 8, 9, "$.foo[1:3]"),
      Token.new(Token::RBRACKET, "]", 9, 10, "$.foo[1:3]"),
      Token.new(Token::EOI, "", 10, 10, "$.foo[1:3]")
    ]
  },
  {
    name: "filter",
    query: "$.foo[?@.bar]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$.foo[?@.bar]"),
      Token.new(Token::NAME, "foo", 2, 5, "$.foo[?@.bar]"),
      Token.new(Token::LBRACKET, "[", 5, 6, "$.foo[?@.bar]"),
      Token.new(Token::FILTER, "?", 6, 7, "$.foo[?@.bar]"),
      Token.new(Token::CURRENT, "@", 7, 8, "$.foo[?@.bar]"),
      Token.new(Token::NAME, "bar", 9, 12, "$.foo[?@.bar]"),
      Token.new(Token::RBRACKET, "]", 12, 13, "$.foo[?@.bar]"),
      Token.new(Token::EOI, "", 13, 13, "$.foo[?@.bar]")
    ]
  },
  {
    name: "filter, parenthesized expression",
    query: "$.foo[?(@.bar)]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$.foo[?(@.bar)]"),
      Token.new(Token::NAME, "foo", 2, 5, "$.foo[?(@.bar)]"),
      Token.new(Token::LBRACKET, "[", 5, 6, "$.foo[?(@.bar)]"),
      Token.new(Token::FILTER, "?", 6, 7, "$.foo[?(@.bar)]"),
      Token.new(Token::LPAREN, "(", 7, 8, "$.foo[?(@.bar)]"),
      Token.new(Token::CURRENT, "@", 8, 9, "$.foo[?(@.bar)]"),
      Token.new(Token::NAME, "bar", 10, 13, "$.foo[?(@.bar)]"),
      Token.new(Token::RPAREN, ")", 13, 14, "$.foo[?(@.bar)]"),
      Token.new(Token::RBRACKET, "]", 14, 15, "$.foo[?(@.bar)]"),
      Token.new(Token::EOI, "", 15, 15, "$.foo[?(@.bar)]")
    ]
  },
  {
    name: "two filters",
    query: "$.foo[?@.bar, ?@.baz]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::NAME, "foo", 2, 5, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::LBRACKET, "[", 5, 6, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::FILTER, "?", 6, 7, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::CURRENT, "@", 7, 8, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::NAME, "bar", 9, 12, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::COMMA, ",", 12, 13, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::FILTER, "?", 14, 15, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::CURRENT, "@", 15, 16, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::NAME, "baz", 17, 20, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::RBRACKET, "]", 20, 21, "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::EOI, "", 21, 21, "$.foo[?@.bar, ?@.baz]")
    ]
  },
  {
    name: "filter, function",
    query: "$[?count(@.foo)>2]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$[?count(@.foo)>2]"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$[?count(@.foo)>2]"),
      Token.new(Token::FILTER, "?", 2, 3, "$[?count(@.foo)>2]"),
      Token.new(Token::FUNCTION, "count", 3, 8, "$[?count(@.foo)>2]"),
      Token.new(Token::CURRENT, "@", 9, 10, "$[?count(@.foo)>2]"),
      Token.new(Token::NAME, "foo", 11, 14, "$[?count(@.foo)>2]"),
      Token.new(Token::RPAREN, ")", 14, 15, "$[?count(@.foo)>2]"),
      Token.new(Token::GT, ">", 15, 16, "$[?count(@.foo)>2]"),
      Token.new(Token::INT, "2", 16, 17, "$[?count(@.foo)>2]"),
      Token.new(Token::RBRACKET, "]", 17, 18, "$[?count(@.foo)>2]"),
      Token.new(Token::EOI, "", 18, 18, "$[?count(@.foo)>2]")
    ]
  },
  {
    name: "filter, function with two args",
    query: "$[?count(@.foo, 1)>2]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::FILTER, "?", 2, 3, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::FUNCTION, "count", 3, 8, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::CURRENT, "@", 9, 10, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::NAME, "foo", 11, 14, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::COMMA, ",", 14, 15, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::INT, "1", 16, 17, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::RPAREN, ")", 17, 18, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::GT, ">", 18, 19, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::INT, "2", 19, 20, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::RBRACKET, "]", 20, 21, "$[?count(@.foo, 1)>2]"),
      Token.new(Token::EOI, "", 21, 21, "$[?count(@.foo, 1)>2]")
    ]
  },
  {
    name: "filter, parenthesized function",
    query: "$[?(count(@.foo)>2)]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$[?(count(@.foo)>2)]"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$[?(count(@.foo)>2)]"),
      Token.new(Token::FILTER, "?", 2, 3, "$[?(count(@.foo)>2)]"),
      Token.new(Token::LPAREN, "(", 3, 4, "$[?(count(@.foo)>2)]"),
      Token.new(Token::FUNCTION, "count", 4, 9, "$[?(count(@.foo)>2)]"),
      Token.new(Token::CURRENT, "@", 10, 11, "$[?(count(@.foo)>2)]"),
      Token.new(Token::NAME, "foo", 12, 15, "$[?(count(@.foo)>2)]"),
      Token.new(Token::RPAREN, ")", 15, 16, "$[?(count(@.foo)>2)]"),
      Token.new(Token::GT, ">", 16, 17, "$[?(count(@.foo)>2)]"),
      Token.new(Token::INT, "2", 17, 18, "$[?(count(@.foo)>2)]"),
      Token.new(Token::RPAREN, ")", 18, 19, "$[?(count(@.foo)>2)]"),
      Token.new(Token::RBRACKET, "]", 19, 20, "$[?(count(@.foo)>2)]"),
      Token.new(Token::EOI, "", 20, 20, "$[?(count(@.foo)>2)]")
    ]
  },
  {
    name: "filter, parenthesized function argument",
    query: "$[?(count((@.foo),1)>2)]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::FILTER, "?", 2, 3, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::LPAREN, "(", 3, 4, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::FUNCTION, "count", 4, 9, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::LPAREN, "(", 10, 11, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::CURRENT, "@", 11, 12, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::NAME, "foo", 13, 16, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::RPAREN, ")", 16, 17, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::COMMA, ",", 17, 18, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::INT, "1", 18, 19, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::RPAREN, ")", 19, 20, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::GT, ">", 20, 21, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::INT, "2", 21, 22, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::RPAREN, ")", 22, 23, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::RBRACKET, "]", 23, 24, "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::EOI, "", 24, 24, "$[?(count((@.foo),1)>2)]")
    ]
  },
  {
    name: "filter, nested",
    query: "$[?@[?@>1]]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$[?@[?@>1]]"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$[?@[?@>1]]"),
      Token.new(Token::FILTER, "?", 2, 3, "$[?@[?@>1]]"),
      Token.new(Token::CURRENT, "@", 3, 4, "$[?@[?@>1]]"),
      Token.new(Token::LBRACKET, "[", 4, 5, "$[?@[?@>1]]"),
      Token.new(Token::FILTER, "?", 5, 6, "$[?@[?@>1]]"),
      Token.new(Token::CURRENT, "@", 6, 7, "$[?@[?@>1]]"),
      Token.new(Token::GT, ">", 7, 8, "$[?@[?@>1]]"),
      Token.new(Token::INT, "1", 8, 9, "$[?@[?@>1]]"),
      Token.new(Token::RBRACKET, "]", 9, 10, "$[?@[?@>1]]"),
      Token.new(Token::RBRACKET, "]", 10, 11, "$[?@[?@>1]]"),
      Token.new(Token::EOI, "", 11, 11, "$[?@[?@>1]]")
    ]
  },
  {
    name: "filter, nested brackets",
    query: "$[?@[?@[1]>1]]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$[?@[?@[1]>1]]"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$[?@[?@[1]>1]]"),
      Token.new(Token::FILTER, "?", 2, 3, "$[?@[?@[1]>1]]"),
      Token.new(Token::CURRENT, "@", 3, 4, "$[?@[?@[1]>1]]"),
      Token.new(Token::LBRACKET, "[", 4, 5, "$[?@[?@[1]>1]]"),
      Token.new(Token::FILTER, "?", 5, 6, "$[?@[?@[1]>1]]"),
      Token.new(Token::CURRENT, "@", 6, 7, "$[?@[?@[1]>1]]"),
      Token.new(Token::LBRACKET, "[", 7, 8, "$[?@[?@[1]>1]]"),
      Token.new(Token::INDEX, "1", 8, 9, "$[?@[?@[1]>1]]"),
      Token.new(Token::RBRACKET, "]", 9, 10, "$[?@[?@[1]>1]]"),
      Token.new(Token::GT, ">", 10, 11, "$[?@[?@[1]>1]]"),
      Token.new(Token::INT, "1", 11, 12, "$[?@[?@[1]>1]]"),
      Token.new(Token::RBRACKET, "]", 12, 13, "$[?@[?@[1]>1]]"),
      Token.new(Token::RBRACKET, "]", 13, 14, "$[?@[?@[1]>1]]"),
      Token.new(Token::EOI, "", 14, 14, "$[?@[?@[1]>1]]")
    ]
  },
  {
    name: "function",
    query: "$[?foo()]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$[?foo()]"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$[?foo()]"),
      Token.new(Token::FILTER, "?", 2, 3, "$[?foo()]"),
      Token.new(Token::FUNCTION, "foo", 3, 6, "$[?foo()]"),
      Token.new(Token::RPAREN, ")", 7, 8, "$[?foo()]"),
      Token.new(Token::RBRACKET, "]", 8, 9, "$[?foo()]"),
      Token.new(Token::EOI, "", 9, 9, "$[?foo()]")
    ]
  },
  {
    name: "function, int literal",
    query: "$[?foo(42)]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$[?foo(42)]"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$[?foo(42)]"),
      Token.new(Token::FILTER, "?", 2, 3, "$[?foo(42)]"),
      Token.new(Token::FUNCTION, "foo", 3, 6, "$[?foo(42)]"),
      Token.new(Token::INT, "42", 7, 9, "$[?foo(42)]"),
      Token.new(Token::RPAREN, ")", 9, 10, "$[?foo(42)]"),
      Token.new(Token::RBRACKET, "]", 10, 11, "$[?foo(42)]"),
      Token.new(Token::EOI, "", 11, 11, "$[?foo(42)]")
    ]
  },
  {
    name: "function, two int args",
    query: "$[?foo(42, -7)]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$[?foo(42, -7)]"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$[?foo(42, -7)]"),
      Token.new(Token::FILTER, "?", 2, 3, "$[?foo(42, -7)]"),
      Token.new(Token::FUNCTION, "foo", 3, 6, "$[?foo(42, -7)]"),
      Token.new(Token::INT, "42", 7, 9, "$[?foo(42, -7)]"),
      Token.new(Token::COMMA, ",", 9, 10, "$[?foo(42, -7)]"),
      Token.new(Token::INT, "-7", 11, 13, "$[?foo(42, -7)]"),
      Token.new(Token::RPAREN, ")", 13, 14, "$[?foo(42, -7)]"),
      Token.new(Token::RBRACKET, "]", 14, 15, "$[?foo(42, -7)]"),
      Token.new(Token::EOI, "", 15, 15, "$[?foo(42, -7)]")
    ]
  },
  {
    name: "boolean literals",
    query: "$[?true==false]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$[?true==false]"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$[?true==false]"),
      Token.new(Token::FILTER, "?", 2, 3, "$[?true==false]"),
      Token.new(Token::TRUE, "true", 3, 7, "$[?true==false]"),
      Token.new(Token::EQ, "==", 7, 9, "$[?true==false]"),
      Token.new(Token::FALSE, "false", 9, 14, "$[?true==false]"),
      Token.new(Token::RBRACKET, "]", 14, 15, "$[?true==false]"),
      Token.new(Token::EOI, "", 15, 15, "$[?true==false]")
    ]
  },
  {
    name: "logical and",
    query: "$[?true && false]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$[?true && false]"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$[?true && false]"),
      Token.new(Token::FILTER, "?", 2, 3, "$[?true && false]"),
      Token.new(Token::TRUE, "true", 3, 7, "$[?true && false]"),
      Token.new(Token::AND, "&&", 8, 10, "$[?true && false]"),
      Token.new(Token::FALSE, "false", 11, 16, "$[?true && false]"),
      Token.new(Token::RBRACKET, "]", 16, 17, "$[?true && false]"),
      Token.new(Token::EOI, "", 17, 17, "$[?true && false]")
    ]
  },
  {
    name: "float",
    query: "$[?@.foo > 42.7]",
    want: [
      Token.new(Token::ROOT, "$", 0, 1, "$[?@.foo > 42.7]"),
      Token.new(Token::LBRACKET, "[", 1, 2, "$[?@.foo > 42.7]"),
      Token.new(Token::FILTER, "?", 2, 3, "$[?@.foo > 42.7]"),
      Token.new(Token::CURRENT, "@", 3, 4, "$[?@.foo > 42.7]"),
      Token.new(Token::NAME, "foo", 5, 8, "$[?@.foo > 42.7]"),
      Token.new(Token::GT, ">", 9, 10, "$[?@.foo > 42.7]"),
      Token.new(Token::FLOAT, "42.7", 11, 15, "$[?@.foo > 42.7]"),
      Token.new(Token::RBRACKET, "]", 15, 16, "$[?@.foo > 42.7]"),
      Token.new(Token::EOI, "", 16, 16, "$[?@.foo > 42.7]")
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
