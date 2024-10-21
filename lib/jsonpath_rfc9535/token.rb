# frozen_string_literal: true

require_relative "errors"

module JSONPathRFC9535
  # Tokens are produced by the lexer and consumed by the parser. Each token contains sub
  # string from a JSONPath expression, its location within the JSONPath expression and a
  # symbol indicating what type of token it is.
  class Token
    EOI = :token_eoi
    ERROR = :token_error

    SHORTHAND_NAME = :token_shorthand_name
    COLON = :token_colon
    COMMA = :token_comma
    DOT = :token_dot
    DOUBLE_DOT = :token_double_dot
    FILTER = :token_filter
    INDEX = :token_index
    LBRACKET = :token_lbracket
    NAME = :token_name
    RBRACKET = :token_rbracket
    ROOT = :token_root
    WILD = :token_wild

    AND = :token_and
    CURRENT = :token_current
    DOUBLE_QUOTE_STRING = :token_double_quote_string
    EQ = :token_eq
    FALSE = :token_false
    FLOAT = :token_float
    FUNCTION = :token_function
    GE = :token_ge
    GT = :token_gt
    INT = :token_int
    LE = :token_le
    LPAREN = :token_lparen
    LT = :token_lt
    NE = :token_ne
    NOT = :token_not
    NULL = :token_null
    OP = :token_op
    OR = :token_or
    RPAREN = :token_rparen
    SINGLE_QUOTE_STRING = :token_single_quote_string
    TRUE = :token_true

    # @dynamic type, value, start, query
    attr_reader :type, :value, :start, :query

    def initialize(type, value, start, query)
      @type = type
      @value = value
      @start = start
      @query = query
    end

    def ==(other)
      self.class == other.class &&
        @type == other.type &&
        @value == other.value &&
        @start == other.start &&
        @query == other.query
    end

    alias eql? ==

    def hash
      [@type, @value].hash
    end

    def deconstruct
      [@type, @value]
    end

    def deconstruct_keys(_)
      { type: @type, value: @value }
    end
  end
end
