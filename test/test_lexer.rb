# frozen_string_literal: true

require "test_helper"

Token = JsonpathRfc9535::Token
Span = JsonpathRfc9535::Span

TEST_CASES = [
  {
    name: "basic shorthand name",
    query: "$.foo.bar",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$.foo.bar"),
      Token.new(Token::NAME, "foo", Span.new(2, 5), "$.foo.bar"),
      Token.new(Token::NAME, "bar", Span.new(6, 9), "$.foo.bar"),
      Token.new(Token::EOI, "", Span.new(9, 9), "$.foo.bar")
    ]
  },
  {
    name: "bracketed name",
    query: "$['foo']['bar']",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$['foo']['bar']"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$['foo']['bar']"),
      Token.new(Token::SINGLE_QUOTE_STRING, "foo", Span.new(3, 6), "$['foo']['bar']"),
      Token.new(Token::RBRACKET, "]", Span.new(7, 8), "$['foo']['bar']"),
      Token.new(Token::LBRACKET, "[", Span.new(8, 9), "$['foo']['bar']"),
      Token.new(Token::SINGLE_QUOTE_STRING, "bar", Span.new(10, 13), "$['foo']['bar']"),
      Token.new(Token::RBRACKET, "]", Span.new(14, 15), "$['foo']['bar']"),
      Token.new(Token::EOI, "", Span.new(15, 15), "$['foo']['bar']")
    ]
  },
  {
    name: "basic index",
    query: "$.foo[1]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$.foo[1]"),
      Token.new(Token::NAME, "foo", Span.new(2, 5), "$.foo[1]"),
      Token.new(Token::LBRACKET, "[", Span.new(5, 6), "$.foo[1]"),
      Token.new(Token::INDEX, "1", Span.new(6, 7), "$.foo[1]"),
      Token.new(Token::RBRACKET, "]", Span.new(7, 8), "$.foo[1]"),
      Token.new(Token::EOI, "", Span.new(8, 8), "$.foo[1]")
    ]
  },
  {
    name: "missing root selector",
    query: "foo.bar",
    want: [
      Token.new(Token::ERROR, "expected '$', found 'f'", Span.new(0, 1), "foo.bar")
    ]
  },
  {
    name: "root property selector without dot",
    query: "$foo",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$foo"),
      Token.new(
        Token::ERROR,
        "expected '.', '..' or a bracketed selection, found 'f'",
        Span.new(1, 2),
        "$foo"
      )
    ]
  },
  {
    name: "whitespace after root",
    query: "$ .foo.bar",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$ .foo.bar"),
      Token.new(Token::NAME, "foo", Span.new(3, 6), "$ .foo.bar"),
      Token.new(Token::NAME, "bar", Span.new(7, 10), "$ .foo.bar"),
      Token.new(Token::EOI, "", Span.new(10, 10), "$ .foo.bar")
    ]
  },
  {
    name: "whitespace before dot property",
    query: "$. foo.bar",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$. foo.bar"),
      Token.new(Token::ERROR, "unexpected whitespace after dot", Span.new(2, 3), "$. foo.bar")
    ]
  },
  {
    name: "whitespace after dot property",
    query: "$.foo .bar",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$.foo .bar"),
      Token.new(Token::NAME, "foo", Span.new(2, 5), "$.foo .bar"),
      Token.new(Token::NAME, "bar", Span.new(7, 10), "$.foo .bar"),
      Token.new(Token::EOI, "", Span.new(10, 10), "$.foo .bar")
    ]
  },
  {
    name: "basic dot wild",
    query: "$.foo.*",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$.foo.*"),
      Token.new(Token::NAME, "foo", Span.new(2, 5), "$.foo.*"),
      Token.new(Token::WILD, "*", Span.new(6, 7), "$.foo.*"),
      Token.new(Token::EOI, "", Span.new(7, 7), "$.foo.*")
    ]
  },
  {
    name: "basic recurse",
    query: "$..foo",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$..foo"),
      Token.new(Token::DOUBLE_DOT, "..", Span.new(1, 3), "$..foo"),
      Token.new(Token::NAME, "foo", Span.new(3, 6), "$..foo"),
      Token.new(Token::EOI, "", Span.new(6, 6), "$..foo")
    ]
  },
  {
    name: "basic recurse with trailing dot",
    query: "$...foo",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$...foo"),
      Token.new(Token::DOUBLE_DOT, "..", Span.new(1, 3), "$...foo"),
      Token.new(
        Token::ERROR,
        "unexpected descendant selection token '.'",
        Span.new(3, 4),
        "$...foo"
      )
    ]
  },
  {
    name: "erroneous double recurse",
    query: "$....foo",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$....foo"),
      Token.new(Token::DOUBLE_DOT, "..", Span.new(1, 3), "$....foo"),
      Token.new(
        Token::ERROR,
        "unexpected descendant selection token '.'",
        Span.new(3, 4),
        "$....foo"
      )
    ]
  },
  {
    name: "bracketed name selector, double quotes",
    query: '$.foo["bar"]',
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), '$.foo["bar"]'),
      Token.new(Token::NAME, "foo", Span.new(2, 5), '$.foo["bar"]'),
      Token.new(Token::LBRACKET, "[", Span.new(5, 6), '$.foo["bar"]'),
      Token.new(Token::DOUBLE_QUOTE_STRING, "bar", Span.new(7, 10), '$.foo["bar"]'),
      Token.new(Token::RBRACKET, "]", Span.new(11, 12), '$.foo["bar"]'),
      Token.new(Token::EOI, "", Span.new(12, 12), '$.foo["bar"]')
    ]
  },
  {
    name: "bracketed name selector, single quotes",
    query: "$.foo['bar']",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$.foo['bar']"),
      Token.new(Token::NAME, "foo", Span.new(2, 5), "$.foo['bar']"),
      Token.new(Token::LBRACKET, "[", Span.new(5, 6), "$.foo['bar']"),
      Token.new(Token::SINGLE_QUOTE_STRING, "bar", Span.new(7, 10), "$.foo['bar']"),
      Token.new(Token::RBRACKET, "]", Span.new(11, 12), "$.foo['bar']"),
      Token.new(Token::EOI, "", Span.new(12, 12), "$.foo['bar']")
    ]
  },
  {
    name: "multiple selectors",
    query: "$.foo['bar', 123, *]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$.foo['bar', 123, *]"),
      Token.new(Token::NAME, "foo", Span.new(2, 5), "$.foo['bar', 123, *]"),
      Token.new(Token::LBRACKET, "[", Span.new(5, 6), "$.foo['bar', 123, *]"),
      Token.new(Token::SINGLE_QUOTE_STRING, "bar", Span.new(7, 10), "$.foo['bar', 123, *]"),
      Token.new(Token::COMMA, ",", Span.new(11, 12), "$.foo['bar', 123, *]"),
      Token.new(Token::INDEX, "123", Span.new(13, 16), "$.foo['bar', 123, *]"),
      Token.new(Token::COMMA, ",", Span.new(16, 17), "$.foo['bar', 123, *]"),
      Token.new(Token::WILD, "*", Span.new(18, 19), "$.foo['bar', 123, *]"),
      Token.new(Token::RBRACKET, "]", Span.new(19, 20), "$.foo['bar', 123, *]"),
      Token.new(Token::EOI, "", Span.new(20, 20), "$.foo['bar', 123, *]")
    ]
  },
  {
    name: "slice",
    query: "$.foo[1:3]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$.foo[1:3]"),
      Token.new(Token::NAME, "foo", Span.new(2, 5), "$.foo[1:3]"),
      Token.new(Token::LBRACKET, "[", Span.new(5, 6), "$.foo[1:3]"),
      Token.new(Token::INDEX, "1", Span.new(6, 7), "$.foo[1:3]"),
      Token.new(Token::COLON, ":", Span.new(7, 8), "$.foo[1:3]"),
      Token.new(Token::INDEX, "3", Span.new(8, 9), "$.foo[1:3]"),
      Token.new(Token::RBRACKET, "]", Span.new(9, 10), "$.foo[1:3]"),
      Token.new(Token::EOI, "", Span.new(10, 10), "$.foo[1:3]")
    ]
  },
  {
    name: "filter",
    query: "$.foo[?@.bar]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$.foo[?@.bar]"),
      Token.new(Token::NAME, "foo", Span.new(2, 5), "$.foo[?@.bar]"),
      Token.new(Token::LBRACKET, "[", Span.new(5, 6), "$.foo[?@.bar]"),
      Token.new(Token::FILTER, "?", Span.new(6, 7), "$.foo[?@.bar]"),
      Token.new(Token::CURRENT, "@", Span.new(7, 8), "$.foo[?@.bar]"),
      Token.new(Token::NAME, "bar", Span.new(9, 12), "$.foo[?@.bar]"),
      Token.new(Token::RBRACKET, "]", Span.new(12, 13), "$.foo[?@.bar]"),
      Token.new(Token::EOI, "", Span.new(13, 13), "$.foo[?@.bar]")
    ]
  },
  {
    name: "filter, parenthesized expression",
    query: "$.foo[?(@.bar)]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$.foo[?(@.bar)]"),
      Token.new(Token::NAME, "foo", Span.new(2, 5), "$.foo[?(@.bar)]"),
      Token.new(Token::LBRACKET, "[", Span.new(5, 6), "$.foo[?(@.bar)]"),
      Token.new(Token::FILTER, "?", Span.new(6, 7), "$.foo[?(@.bar)]"),
      Token.new(Token::LPAREN, "(", Span.new(7, 8), "$.foo[?(@.bar)]"),
      Token.new(Token::CURRENT, "@", Span.new(8, 9), "$.foo[?(@.bar)]"),
      Token.new(Token::NAME, "bar", Span.new(10, 13), "$.foo[?(@.bar)]"),
      Token.new(Token::RPAREN, ")", Span.new(13, 14), "$.foo[?(@.bar)]"),
      Token.new(Token::RBRACKET, "]", Span.new(14, 15), "$.foo[?(@.bar)]"),
      Token.new(Token::EOI, "", Span.new(15, 15), "$.foo[?(@.bar)]")
    ]
  },
  {
    name: "two filters",
    query: "$.foo[?@.bar, ?@.baz]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::NAME, "foo", Span.new(2, 5), "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::LBRACKET, "[", Span.new(5, 6), "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::FILTER, "?", Span.new(6, 7), "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::CURRENT, "@", Span.new(7, 8), "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::NAME, "bar", Span.new(9, 12), "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::COMMA, ",", Span.new(12, 13), "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::FILTER, "?", Span.new(14, 15), "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::CURRENT, "@", Span.new(15, 16), "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::NAME, "baz", Span.new(17, 20), "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::RBRACKET, "]", Span.new(20, 21), "$.foo[?@.bar, ?@.baz]"),
      Token.new(Token::EOI, "", Span.new(21, 21), "$.foo[?@.bar, ?@.baz]")
    ]
  },
  {
    name: "filter, function",
    query: "$[?count(@.foo)>2]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$[?count(@.foo)>2]"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$[?count(@.foo)>2]"),
      Token.new(Token::FILTER, "?", Span.new(2, 3), "$[?count(@.foo)>2]"),
      Token.new(Token::FUNCTION, "count", Span.new(3, 8), "$[?count(@.foo)>2]"),
      Token.new(Token::CURRENT, "@", Span.new(9, 10), "$[?count(@.foo)>2]"),
      Token.new(Token::NAME, "foo", Span.new(11, 14), "$[?count(@.foo)>2]"),
      Token.new(Token::RPAREN, ")", Span.new(14, 15), "$[?count(@.foo)>2]"),
      Token.new(Token::GT, ">", Span.new(15, 16), "$[?count(@.foo)>2]"),
      Token.new(Token::INT, "2", Span.new(16, 17), "$[?count(@.foo)>2]"),
      Token.new(Token::RBRACKET, "]", Span.new(17, 18), "$[?count(@.foo)>2]"),
      Token.new(Token::EOI, "", Span.new(18, 18), "$[?count(@.foo)>2]")
    ]
  },
  {
    name: "filter, function with two args",
    query: "$[?count(@.foo, 1)>2]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$[?count(@.foo, 1)>2]"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$[?count(@.foo, 1)>2]"),
      Token.new(Token::FILTER, "?", Span.new(2, 3), "$[?count(@.foo, 1)>2]"),
      Token.new(Token::FUNCTION, "count", Span.new(3, 8), "$[?count(@.foo, 1)>2]"),
      Token.new(Token::CURRENT, "@", Span.new(9, 10), "$[?count(@.foo, 1)>2]"),
      Token.new(Token::NAME, "foo", Span.new(11, 14), "$[?count(@.foo, 1)>2]"),
      Token.new(Token::COMMA, ",", Span.new(14, 15), "$[?count(@.foo, 1)>2]"),
      Token.new(Token::INT, "1", Span.new(16, 17), "$[?count(@.foo, 1)>2]"),
      Token.new(Token::RPAREN, ")", Span.new(17, 18), "$[?count(@.foo, 1)>2]"),
      Token.new(Token::GT, ">", Span.new(18, 19), "$[?count(@.foo, 1)>2]"),
      Token.new(Token::INT, "2", Span.new(19, 20), "$[?count(@.foo, 1)>2]"),
      Token.new(Token::RBRACKET, "]", Span.new(20, 21), "$[?count(@.foo, 1)>2]"),
      Token.new(Token::EOI, "", Span.new(21, 21), "$[?count(@.foo, 1)>2]")
    ]
  },
  {
    name: "filter, parenthesized function",
    query: "$[?(count(@.foo)>2)]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$[?(count(@.foo)>2)]"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$[?(count(@.foo)>2)]"),
      Token.new(Token::FILTER, "?", Span.new(2, 3), "$[?(count(@.foo)>2)]"),
      Token.new(Token::LPAREN, "(", Span.new(3, 4), "$[?(count(@.foo)>2)]"),
      Token.new(Token::FUNCTION, "count", Span.new(4, 9), "$[?(count(@.foo)>2)]"),
      Token.new(Token::CURRENT, "@", Span.new(10, 11), "$[?(count(@.foo)>2)]"),
      Token.new(Token::NAME, "foo", Span.new(12, 15), "$[?(count(@.foo)>2)]"),
      Token.new(Token::RPAREN, ")", Span.new(15, 16), "$[?(count(@.foo)>2)]"),
      Token.new(Token::GT, ">", Span.new(16, 17), "$[?(count(@.foo)>2)]"),
      Token.new(Token::INT, "2", Span.new(17, 18), "$[?(count(@.foo)>2)]"),
      Token.new(Token::RPAREN, ")", Span.new(18, 19), "$[?(count(@.foo)>2)]"),
      Token.new(Token::RBRACKET, "]", Span.new(19, 20), "$[?(count(@.foo)>2)]"),
      Token.new(Token::EOI, "", Span.new(20, 20), "$[?(count(@.foo)>2)]")
    ]
  },
  {
    name: "filter, parenthesized function argument",
    query: "$[?(count((@.foo),1)>2)]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::FILTER, "?", Span.new(2, 3), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::LPAREN, "(", Span.new(3, 4), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::FUNCTION, "count", Span.new(4, 9), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::LPAREN, "(", Span.new(10, 11), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::CURRENT, "@", Span.new(11, 12), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::NAME, "foo", Span.new(13, 16), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::RPAREN, ")", Span.new(16, 17), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::COMMA, ",", Span.new(17, 18), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::INT, "1", Span.new(18, 19), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::RPAREN, ")", Span.new(19, 20), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::GT, ">", Span.new(20, 21), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::INT, "2", Span.new(21, 22), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::RPAREN, ")", Span.new(22, 23), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::RBRACKET, "]", Span.new(23, 24), "$[?(count((@.foo),1)>2)]"),
      Token.new(Token::EOI, "", Span.new(24, 24), "$[?(count((@.foo),1)>2)]")
    ]
  },
  {
    name: "filter, nested",
    query: "$[?@[?@>1]]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$[?@[?@>1]]"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$[?@[?@>1]]"),
      Token.new(Token::FILTER, "?", Span.new(2, 3), "$[?@[?@>1]]"),
      Token.new(Token::CURRENT, "@", Span.new(3, 4), "$[?@[?@>1]]"),
      Token.new(Token::LBRACKET, "[", Span.new(4, 5), "$[?@[?@>1]]"),
      Token.new(Token::FILTER, "?", Span.new(5, 6), "$[?@[?@>1]]"),
      Token.new(Token::CURRENT, "@", Span.new(6, 7), "$[?@[?@>1]]"),
      Token.new(Token::GT, ">", Span.new(7, 8), "$[?@[?@>1]]"),
      Token.new(Token::INT, "1", Span.new(8, 9), "$[?@[?@>1]]"),
      Token.new(Token::RBRACKET, "]", Span.new(9, 10), "$[?@[?@>1]]"),
      Token.new(Token::RBRACKET, "]", Span.new(10, 11), "$[?@[?@>1]]"),
      Token.new(Token::EOI, "", Span.new(11, 11), "$[?@[?@>1]]")
    ]
  },
  {
    name: "filter, nested brackets",
    query: "$[?@[?@[1]>1]]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$[?@[?@[1]>1]]"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$[?@[?@[1]>1]]"),
      Token.new(Token::FILTER, "?", Span.new(2, 3), "$[?@[?@[1]>1]]"),
      Token.new(Token::CURRENT, "@", Span.new(3, 4), "$[?@[?@[1]>1]]"),
      Token.new(Token::LBRACKET, "[", Span.new(4, 5), "$[?@[?@[1]>1]]"),
      Token.new(Token::FILTER, "?", Span.new(5, 6), "$[?@[?@[1]>1]]"),
      Token.new(Token::CURRENT, "@", Span.new(6, 7), "$[?@[?@[1]>1]]"),
      Token.new(Token::LBRACKET, "[", Span.new(7, 8), "$[?@[?@[1]>1]]"),
      Token.new(Token::INDEX, "1", Span.new(8, 9), "$[?@[?@[1]>1]]"),
      Token.new(Token::RBRACKET, "]", Span.new(9, 10), "$[?@[?@[1]>1]]"),
      Token.new(Token::GT, ">", Span.new(10, 11), "$[?@[?@[1]>1]]"),
      Token.new(Token::INT, "1", Span.new(11, 12), "$[?@[?@[1]>1]]"),
      Token.new(Token::RBRACKET, "]", Span.new(12, 13), "$[?@[?@[1]>1]]"),
      Token.new(Token::RBRACKET, "]", Span.new(13, 14), "$[?@[?@[1]>1]]"),
      Token.new(Token::EOI, "", Span.new(14, 14), "$[?@[?@[1]>1]]")
    ]
  },
  {
    name: "function",
    query: "$[?foo()]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$[?foo()]"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$[?foo()]"),
      Token.new(Token::FILTER, "?", Span.new(2, 3), "$[?foo()]"),
      Token.new(Token::FUNCTION, "foo", Span.new(3, 6), "$[?foo()]"),
      Token.new(Token::RPAREN, ")", Span.new(7, 8), "$[?foo()]"),
      Token.new(Token::RBRACKET, "]", Span.new(8, 9), "$[?foo()]"),
      Token.new(Token::EOI, "", Span.new(9, 9), "$[?foo()]")
    ]
  },
  {
    name: "function, int literal",
    query: "$[?foo(42)]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$[?foo(42)]"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$[?foo(42)]"),
      Token.new(Token::FILTER, "?", Span.new(2, 3), "$[?foo(42)]"),
      Token.new(Token::FUNCTION, "foo", Span.new(3, 6), "$[?foo(42)]"),
      Token.new(Token::INT, "42", Span.new(7, 9), "$[?foo(42)]"),
      Token.new(Token::RPAREN, ")", Span.new(9, 10), "$[?foo(42)]"),
      Token.new(Token::RBRACKET, "]", Span.new(10, 11), "$[?foo(42)]"),
      Token.new(Token::EOI, "", Span.new(11, 11), "$[?foo(42)]")
    ]
  },
  {
    name: "function, two int args",
    query: "$[?foo(42, -7)]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$[?foo(42, -7)]"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$[?foo(42, -7)]"),
      Token.new(Token::FILTER, "?", Span.new(2, 3), "$[?foo(42, -7)]"),
      Token.new(Token::FUNCTION, "foo", Span.new(3, 6), "$[?foo(42, -7)]"),
      Token.new(Token::INT, "42", Span.new(7, 9), "$[?foo(42, -7)]"),
      Token.new(Token::COMMA, ",", Span.new(9, 10), "$[?foo(42, -7)]"),
      Token.new(Token::INT, "-7", Span.new(11, 13), "$[?foo(42, -7)]"),
      Token.new(Token::RPAREN, ")", Span.new(13, 14), "$[?foo(42, -7)]"),
      Token.new(Token::RBRACKET, "]", Span.new(14, 15), "$[?foo(42, -7)]"),
      Token.new(Token::EOI, "", Span.new(15, 15), "$[?foo(42, -7)]")
    ]
  },
  {
    name: "boolean literals",
    query: "$[?true==false]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$[?true==false]"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$[?true==false]"),
      Token.new(Token::FILTER, "?", Span.new(2, 3), "$[?true==false]"),
      Token.new(Token::TRUE, "true", Span.new(3, 7), "$[?true==false]"),
      Token.new(Token::EQ, "==", Span.new(7, 9), "$[?true==false]"),
      Token.new(Token::FALSE, "false", Span.new(9, 14), "$[?true==false]"),
      Token.new(Token::RBRACKET, "]", Span.new(14, 15), "$[?true==false]"),
      Token.new(Token::EOI, "", Span.new(15, 15), "$[?true==false]")
    ]
  },
  {
    name: "logical and",
    query: "$[?true && false]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$[?true && false]"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$[?true && false]"),
      Token.new(Token::FILTER, "?", Span.new(2, 3), "$[?true && false]"),
      Token.new(Token::TRUE, "true", Span.new(3, 7), "$[?true && false]"),
      Token.new(Token::AND, "&&", Span.new(8, 10), "$[?true && false]"),
      Token.new(Token::FALSE, "false", Span.new(11, 16), "$[?true && false]"),
      Token.new(Token::RBRACKET, "]", Span.new(16, 17), "$[?true && false]"),
      Token.new(Token::EOI, "", Span.new(17, 17), "$[?true && false]")
    ]
  },
  {
    name: "float",
    query: "$[?@.foo > 42.7]",
    want: [
      Token.new(Token::ROOT, "$", Span.new(0, 1), "$[?@.foo > 42.7]"),
      Token.new(Token::LBRACKET, "[", Span.new(1, 2), "$[?@.foo > 42.7]"),
      Token.new(Token::FILTER, "?", Span.new(2, 3), "$[?@.foo > 42.7]"),
      Token.new(Token::CURRENT, "@", Span.new(3, 4), "$[?@.foo > 42.7]"),
      Token.new(Token::NAME, "foo", Span.new(5, 8), "$[?@.foo > 42.7]"),
      Token.new(Token::GT, ">", Span.new(9, 10), "$[?@.foo > 42.7]"),
      Token.new(Token::FLOAT, "42.7", Span.new(11, 15), "$[?@.foo > 42.7]"),
      Token.new(Token::RBRACKET, "]", Span.new(15, 16), "$[?@.foo > 42.7]"),
      Token.new(Token::EOI, "", Span.new(16, 16), "$[?@.foo > 42.7]")
    ]
  }
].freeze

class TestLexer < Minitest::Spec
  make_my_diffs_pretty!

  describe "tokenize queries" do
    TEST_CASES.each do |test_case|
      it test_case[:name] do
        lexer = JsonpathRfc9535::Lexer.new(test_case[:query])
        lexer.run
        _(lexer.tokens).must_equal test_case[:want]
      end
    end
  end
end
