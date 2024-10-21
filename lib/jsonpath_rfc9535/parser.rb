# frozen_string_literal: true

require "json"
require "set"

require_relative "errors"
require_relative "filter"
require_relative "function"
require_relative "segment"
require_relative "selector"
require_relative "token"
require_relative "unescape"

module JSONPathRFC9535
  # Step through tokens
  class Stream
    def initialize(tokens)
      @tokens = tokens
      @index = 0
      @eoi = tokens.last
    end

    def next
      token = @tokens.fetch(@index)
      @index += 1
      token
    rescue IndexError
      @eor
    end

    def peek
      @tokens.fetch(@index)
    rescue IndexError
      @eor
    end

    def expect(token_type)
      return if peek.type == token_type

      token = self.next
      raise JSONPathSyntaxError.new("expected #{token_type}, found #{token.type}", token)
    end

    def expect_not(token_type, message)
      return unless peek.type == token_type

      token = self.next
      raise JSONPathSyntaxError.new(message, token)
    end

    def to_s
      "JSONPathRFC9535::stream(head=#{peek.inspect})"
    end
  end

  class Precedence
    LOWEST = 1
    LOGICAL_OR = 3
    LOGICAL_AND = 4
    RELATIONAL = 5
    PREFIX = 7
  end

  # A JSONPath expression parser.
  class Parser # rubocop:disable Metrics/ClassLength
    def initialize(env)
      @env = env
    end

    # Parse an array of tokens into an abstract syntax tree.
    # @param tokens [Array<Token>] tokens from the lexer.
    # @return [Array<Segment>]
    def parse(tokens)
      stream = Stream.new(tokens)
      stream.expect(Token::ROOT)
      stream.next
      parse_query(stream)
    end

    protected

    def parse_query(stream) # rubocop:disable Metrics/MethodLength
      segments = []

      loop do
        case stream.peek.type
        when Token::DOUBLE_DOT
          token = stream.next
          selectors = parse_selectors(stream)
          segments << RecursiveDescentSegment.new(@env, token, selectors)
        when Token::LBRACKET, Token::NAME, Token::WILD
          token = stream.peek
          selectors = parse_selectors(stream)
          segments << ChildSegment.new(@env, token, selectors)
        else
          break
        end
      end

      segments
    end

    def parse_selectors(stream) # rubocop:disable Metrics/MethodLength
      case stream.peek.type
      when Token::NAME
        token = stream.next
        [NameSelector.new(@env, token, token.value)]
      when Token::WILD
        [WildcardSelector.new(@env, stream.next)]
      when Token::LBRACKET
        parse_bracketed_selection(stream)
      else
        []
      end
    end

    def parse_bracketed_selection(stream) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
      stream.expect Token::LBRACKET
      segment_token = stream.next

      selectors = []

      loop do # rubocop:disable Metrics/BlockLength
        case stream.peek.type
        when Token::RBRACKET
          break
        when Token::INDEX
          selectors << parse_index_or_slice(stream)
        when Token::DOUBLE_QUOTE_STRING, Token::SINGLE_QUOTE_STRING
          token = stream.next
          selectors << NameSelector.new(@env, token, decode_string_literal(token))
        when Token::COLON
          selectors << parse_slice_selector(stream)
        when Token::WILD
          selectors << WildcardSelector.new(@env, stream.next)
        when Token::FILTER
          selectors << parse_filter_selector(stream)
        when Token::EOI
          raise JSONPathSyntaxError.new("unexpected end of query", stream.next)
        else
          raise JSONPathSyntaxError.new("unexpected token in bracketed selection", stream.next)
        end

        case stream.peek.type
        when Token::EOI
          raise JSONPathSyntaxError.new("unexpected end of selector list", stream.next)
        when Token::RBRACKET
          break
        else
          stream.expect Token::COMMA
          stream.next
          stream.expect_not(Token::RBRACKET, "unexpected trailing comma")
        end
      end

      stream.expect(Token::RBRACKET)
      stream.next

      raise JSONPathSyntaxError.new("empty segment", segment_token) if selectors.empty?

      selectors
    end

    def parse_index_or_slice(stream) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      token = stream.next
      index = parse_i_json_int(token)

      return IndexSelector.new(@env, token, index) unless stream.peek.type == Token::COLON

      stream.next # move past colon
      stop = nil
      step = nil

      case stream.peek.type
      when Token::INDEX
        stop = parse_i_json_int(stream.next)
      when Token::COLON
        stream.next # move past colon
      end

      stream.next if stream.peek.type == Token::COLON

      case stream.peek.type
      when Token::INDEX
        step = parse_i_json_int(stream.next)
      when Token::RBRACKET
        nil
      else
        error_token = stream.next
        raise JSONPathSyntaxError.new("expected a slice, found '#{error_token.value}'", error_token)
      end

      SliceSelector.new(@env, token, index, stop, step)
    end

    def parse_slice_selector(stream) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      stream.expect(Token::COLON)
      token = stream.next

      start = nil
      stop = nil
      step = nil

      case stream.peek.type
      when Token::INDEX
        stop = parse_i_json_int(stream.next)
      when Token::COLON
        stream.next # move past colon
      end

      stream.next if stream.peek.type == Token::COLON

      case stream.peek.type
      when Token::INDEX
        step = parse_i_json_int(stream.next)
      when Token::RBRACKET
        nil
      else
        error_token = stream.next
        raise JSONPathSyntaxError.new("expected a slice, found '#{token.value}'", error_token)
      end

      SliceSelector.new(@env, token, start, stop, step)
    end

    def parse_filter_selector(stream) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      token = stream.next
      expression = parse_filter_expression(stream)

      # Raise if expression must be compared.
      if expression.is_a? FunctionExpression
        func = @env.function_extensions[expression.name]
        if func.class::RETURN_TYPE == ExpressionType::VALUE
          raise JSONPathTypeError.new("result of #{expression.name}() must be compared", expression.token)
        end
      end

      # Raise if expression is a literal.
      if expression.is_a? FilterExpressionLiteral
        raise JSONPathSyntaxError.new("filter expression literals must be compared", expression.token)
      end

      FilterSelector.new(@env, token, FilterExpression.new(token, expression))
    end

    def parse_filter_expression(stream, precedence = Precedence::LOWEST) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
      left = case stream.peek.type
             when Token::DOUBLE_QUOTE_STRING, Token::SINGLE_QUOTE_STRING
               token = stream.next
               StringLiteral.new(token, decode_string_literal(token))
             when Token::FALSE
               BooleanLiteral.new(stream.next, false)
             when Token::TRUE
               BooleanLiteral.new(stream.next, true)
             when Token::FLOAT
               parse_float_literal(stream)
             when Token::FUNCTION
               parse_function_expression(stream)
             when Token::INT
               parse_integer_literal(stream)
             when Token::LPAREN
               parse_grouped_expression(stream)
             when Token::NOT
               parse_prefix_expression(stream)
             when Token::NULL
               NullLiteral.new(stream.next, nil)
             when Token::ROOT
               parse_root_query(stream)
             when Token::CURRENT
               parse_relative_query(stream)
             else
               token = stream.next
               raise JSONPathSyntaxError.new("unexpected '#{token.value}'", token)
             end

      loop do
        peeked = stream.peek
        if peeked.type == Token::EOI ||
           peeked.type == Token::RBRACKET ||
           PRECEDENCES.fetch(peeked.type, Precedence::LOWEST) < precedence
          break
        end

        return left unless BINARY_OPERATORS.key?(peeked.type)

        left = parse_infix_expression(stream, left)
      end

      left
    end

    def parse_integer_literal(stream)
      token = stream.next
      value = token.value
      raise JSONPathSyntaxError.new("invalid integer literal", token) if value.start_with?("0") && value.length > 1

      IntegerLiteral.new(token, Integer(Float(token.value)))
    end

    def parse_float_literal(stream)
      token = stream.next
      value = token.value
      if value.start_with?("0") && value.split(".").first.length > 1
        raise JSONPathSyntaxError.new("invalid float literal", token)
      end

      begin
        FloatLiteral.new(token, Float(value))
      rescue ArgumentError
        raise JSONPathSyntaxError.new("invalid float literal", token)
      end
    end

    def parse_function_expression(stream) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
      token = stream.next
      args = []

      while stream.peek.type != Token::RPAREN
        expr = case stream.peek.type
               when Token::DOUBLE_QUOTE_STRING, Token::SINGLE_QUOTE_STRING
                 arg_token = stream.next
                 StringLiteral.new(arg_token, decode_string_literal(arg_token))
               when Token::FALSE
                 BooleanLiteral.new(stream.next, false)
               when Token::TRUE
                 BooleanLiteral.new(stream.next, true)
               when Token::FLOAT
                 parse_float_literal(stream)
               when Token::FUNCTION
                 parse_function_expression(stream)
               when Token::INT
                 parse_integer_literal(stream)
               when Token::NULL
                 NullLiteral.new(stream.next, nil)
               when Token::ROOT
                 parse_root_query(stream)
               when Token::CURRENT
                 parse_relative_query(stream)
               else
                 arg_token = stream.next
                 raise JSONPathSyntaxError.new("unexpected '#{arg_token.value}'", arg_token)
               end

        expr = parse_infix_expression(stream, expr) while BINARY_OPERATORS.key? stream.peek.type

        args << expr

        if stream.peek.type != Token::RPAREN
          stream.expect(Token::COMMA)
          stream.next
        end
      end

      stream.expect(Token::RPAREN)
      stream.next

      validate_function_extension_sugnature(token, args)
      FunctionExpression.new(token, token.value, args)
    end

    def parse_grouped_expression(stream)
      stream.next # discard "("
      expr = parse_filter_expression(stream)

      while stream.peek.type != Token::RPAREN
        raise JSONPathSyntaxError.new("unbalanced parentheses", stream.peek) if stream.peek.type == Token::EOI

        expr = parse_infix_expression(stream, expr)
      end

      stream.expect(Token::RPAREN)
      stream.next
      expr
    end

    def parse_prefix_expression(stream)
      token = stream.next
      LogicalNotExpression.new(token, parse_filter_expression(stream, Precedence::PREFIX))
    end

    def parse_root_query(stream)
      token = stream.next
      RootQueryExpression.new(token, JSONPath.new(@env, parse_query(stream)))
    end

    def parse_relative_query(stream)
      token = stream.next
      RelativeQueryExpression.new(token, JSONPath.new(@env, parse_query(stream)))
    end

    def parse_infix_expression(stream, left) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
      token = stream.next
      precedence = PRECEDENCES.fetch(token.type, Precedence::LOWEST)
      right = parse_filter_expression(stream, precedence)

      if COMPARISON_OPERATORS.member? token.value
        raise_for_non_comparable_function(left)
        raise_for_non_comparable_function(right)
        case token.type
        when Token::EQ
          EqExpression.new(token, left, right)
        when Token::GE
          GeExpression.new(token, left, right)
        when Token::GT
          GtExpression.new(token, left, right)
        when Token::LE
          LeExpression.new(token, left, right)
        when Token::LT
          LtExpression.new(token, left, right)
        when Token::NE
          NeExpression.new(token, left, right)
        else
          raise JSONPathSyntaxError.new("unexpected token", token)
        end
      else
        raise_for_uncompared_literal(left)
        raise_for_uncompared_literal(right)
        case token.type
        when Token::AND
          LogicalAndExpression.new(token, left, right)
        when Token::OR
          LogicalOrExpression.new(token, left, right)
        else
          raise JSONPathSyntaxError.new("unexpected token", token)
        end
      end
    end

    def parse_i_json_int(token) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      value = token.value

      if value.length > 1 && value.start_with?("0", "-0")
        raise JSONPathSyntaxError.new("invalid index '#{value}'", token)
      end

      begin
        int = Integer(value)
      rescue ArgumentError
        raise JSONPathSyntaxError.new("invalid I-JSON integer", token)
      end

      raise JSONPathSyntaxError.new("index out of range", token) if int < -(2**53) + 1 || int > (2**53) - 1

      int
    end

    def decode_string_literal(token)
      if token.type == Token::SINGLE_QUOTE_STRING
        JSONPathRFC9535.unescape_string(token.value, "'", token)
      else
        JSONPathRFC9535.unescape_string(token.value, '"', token)
      end
    end

    def raise_for_non_comparable_function(expression)
      if expression.is_a?(QueryExpression) && !expression.query.singular?
        raise JSONPathSyntaxError.new("non-singular query is not comparable", expression.token)
      end

      return unless expression.is_a?(FunctionExpression)

      func = @env.function_extensions[expression.name]
      return unless func.class::RETURN_TYPE != ExpressionType::VALUE

      raise JSONPathTypeError.new("result of #{expression.name}() is not comparable", expression.token)
    end

    def raise_for_uncompared_literal(expression)
      return unless expression.is_a? FilterExpressionLiteral

      raise JSONPathSyntaxError.new("expression literals must be compared",
                                    expression.token)
    end

    def validate_function_extension_sugnature(token, args) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      func = @env.function_extensions.fetch(token.value)

      unless args.length == func.class::ARG_TYPES.length
        raise JSONPathTypeError.new(
          "#{token.value}() takes #{func.class::ARG_TYPES.length} arguments (#{args.length} given)",
          token
        )
      end

      func.class::ARG_TYPES.each_with_index do |t, i|
        arg = args[i]
        case t
        when ExpressionType::VALUE
          unless arg.is_a?(FilterExpressionLiteral) ||
                 (arg.is_a?(QueryExpression) && arg.query.singular?) ||
                 (function_return_type(arg) == ExpressionType::VALUE)
            raise JSONPathTypeError.new("#{token.value}() argument #{i} must be of ValueType", arg.token)
          end
        when ExpressionType::LOGICAL
          unless arg.is_a?(QueryExpression) || arg.is_a?(InfixExpression)
            raise JSONPathTypeError.new("#{token.value}() argument #{i} must be of LogicalType", arg.token)
          end
        when ExpressionType::NODES
          unless arg.is_a?(QueryExpression) || function_return_type(arg) == ExpressionType::NODES
            raise JSONPathTypeError.new("#{token.value}() argument #{i} must be of NodesType", arg.token)
          end
        end
      end
    rescue KeyError
      raise JSONPathNameError.new("function '#{token.value}' is not defined", token)
    end

    def function_return_type(expression)
      return nil unless expression.is_a? FunctionExpression

      @env.function_extensions[expression.name].class::RETURN_TYPE
    end

    PRECEDENCES = {
      Token::AND => Precedence::LOGICAL_AND,
      Token::OR => Precedence::LOGICAL_OR,
      Token::NOT => Precedence::PREFIX,
      Token::EQ => Precedence::RELATIONAL,
      Token::GE => Precedence::RELATIONAL,
      Token::GT => Precedence::RELATIONAL,
      Token::LE => Precedence::RELATIONAL,
      Token::LT => Precedence::RELATIONAL,
      Token::NE => Precedence::RELATIONAL,
      Token::RPAREN => Precedence::LOWEST
    }.freeze

    BINARY_OPERATORS = {
      Token::AND => "&&",
      Token::OR => "||",
      Token::EQ => "==",
      Token::GE => ">=",
      Token::GT => ">",
      Token::LE => "<=",
      Token::LT => "<",
      Token::NE => "!="
    }.freeze

    COMPARISON_OPERATORS = Set[
      "==",
      ">=",
      ">",
      "<=",
      "<",
      "!=",
    ]
  end
end
