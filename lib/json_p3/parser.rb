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

module JSONP3
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
      "JSONP3::stream(head=#{peek.inspect})"
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
  class Parser
    def initialize(env)
      @env = env
      @name_selector = env.class::NAME_SELECTOR
      @index_selector = env.class::INDEX_SELECTOR
    end

    # Parse an array of tokens into an abstract syntax tree.
    # @param tokens [Array<Token>] tokens from the lexer.
    # @return [Array<Segment>]
    def parse(tokens)
      stream = Stream.new(tokens)
      stream.expect(:token_root)
      stream.next
      parse_query(stream)
    end

    protected

    def parse_query(stream)
      segments = [] # : Array[Segment]

      loop do
        case stream.peek.type
        when :token_double_dot
          token = stream.next
          selectors = parse_selectors(stream)
          segments << RecursiveDescentSegment.new(@env, token, selectors)
        when :token_lbracket, :token_name, :token_wild
          token = stream.peek
          selectors = parse_selectors(stream)
          segments << ChildSegment.new(@env, token, selectors)
        else
          break
        end
      end

      segments
    end

    def parse_selectors(stream)
      case stream.peek.type
      when :token_name
        token = stream.next
        [@name_selector.new(@env, token, token.value)]
      when :token_wild
        [WildcardSelector.new(@env, stream.next)]
      when :token_lbracket
        parse_bracketed_selection(stream)
      else
        []
      end
    end

    def parse_bracketed_selection(stream)
      stream.expect(:token_lbracket)
      segment_token = stream.next

      selectors = [] # : Array[Selector]

      loop do # rubocop:disable Metrics/BlockLength
        case stream.peek.type
        when :token_rbracket
          break
        when :token_index
          selectors << parse_index_or_slice(stream)
        when :token_double_quote_string, :token_single_quote_string
          token = stream.next
          selectors << @name_selector.new(@env, token, decode_string_literal(token))
        when :token_colon
          selectors << parse_slice_selector(stream)
        when :token_wild
          selectors << WildcardSelector.new(@env, stream.next)
        when :token_filter
          selectors << parse_filter_selector(stream)
        when :token_eoi
          raise JSONPathSyntaxError.new("unexpected end of query", stream.next)
        else
          raise JSONPathSyntaxError.new("unexpected token in bracketed selection", stream.next)
        end

        case stream.peek.type
        when :token_eoi
          raise JSONPathSyntaxError.new("unexpected end of selector list", stream.next)
        when :token_rbracket
          break
        else
          stream.expect(:token_comma)
          stream.next
          stream.expect_not(:token_rbracket, "unexpected trailing comma")
        end
      end

      stream.expect(:token_rbracket)
      stream.next

      raise JSONPathSyntaxError.new("empty segment", segment_token) if selectors.empty?

      selectors
    end

    def parse_index_or_slice(stream)
      token = stream.next
      index = parse_i_json_int(token)

      return @index_selector.new(@env, token, index) unless stream.peek.type == :token_colon

      stream.next # move past colon
      stop = nil
      step = nil

      case stream.peek.type
      when :token_index
        stop = parse_i_json_int(stream.next)
      when :token_colon
        stream.next # move past colon
      end

      stream.next if stream.peek.type == :token_colon

      case stream.peek.type
      when :token_index
        step = parse_i_json_int(stream.next)
      when :token_rbracket
        nil
      else
        error_token = stream.next
        raise JSONPathSyntaxError.new("expected a slice, found '#{error_token.value}'", error_token)
      end

      SliceSelector.new(@env, token, index, stop, step)
    end

    def parse_slice_selector(stream)
      stream.expect(:token_colon)
      token = stream.next

      start = nil
      stop = nil
      step = nil

      case stream.peek.type
      when :token_index
        stop = parse_i_json_int(stream.next)
      when :token_colon
        stream.next # move past colon
      end

      stream.next if stream.peek.type == :token_colon

      case stream.peek.type
      when :token_index
        step = parse_i_json_int(stream.next)
      when :token_rbracket
        nil
      else
        error_token = stream.next
        raise JSONPathSyntaxError.new("expected a slice, found '#{token.value}'", error_token)
      end

      SliceSelector.new(@env, token, start, stop, step)
    end

    def parse_filter_selector(stream)
      token = stream.next
      expression = parse_filter_expression(stream)

      # Raise if expression must be compared.
      if expression.is_a? FunctionExpression
        func = @env.function_extensions[expression.name]
        if func.class::RETURN_TYPE == :value_expression
          raise JSONPathTypeError.new("result of #{expression.name}() must be compared", expression.token)
        end
      end

      # Raise if expression is a literal.
      if expression.is_a? FilterExpressionLiteral
        raise JSONPathSyntaxError.new("filter expression literals must be compared", expression.token)
      end

      FilterSelector.new(@env, token, FilterExpression.new(token, expression))
    end

    def parse_filter_expression(stream, precedence = Precedence::LOWEST)
      left = case stream.peek.type
             when :token_double_quote_string, :token_single_quote_string
               token = stream.next
               StringLiteral.new(token, decode_string_literal(token))
             when :token_false
               BooleanLiteral.new(stream.next, false)
             when :token_true
               BooleanLiteral.new(stream.next, true)
             when :token_float
               parse_float_literal(stream)
             when :token_function
               parse_function_expression(stream)
             when :token_int
               parse_integer_literal(stream)
             when :token_lparen
               parse_grouped_expression(stream)
             when :token_not
               parse_prefix_expression(stream)
             when :token_null
               NullLiteral.new(stream.next, nil)
             when :token_root
               parse_root_query(stream)
             when :token_current
               parse_relative_query(stream)
             else
               token = stream.next
               raise JSONPathSyntaxError.new("unexpected '#{token.value}'", token)
             end

      loop do
        peeked = stream.peek
        if peeked.type == :token_eoi ||
           peeked.type == :token_rbracket ||
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

    def parse_function_expression(stream)
      token = stream.next
      args = [] # : Array[Expression]

      while stream.peek.type != :token_rparen
        expr = case stream.peek.type
               when :token_double_quote_string, :token_single_quote_string
                 arg_token = stream.next
                 StringLiteral.new(arg_token, decode_string_literal(arg_token))
               when :token_false
                 BooleanLiteral.new(stream.next, false)
               when :token_true
                 BooleanLiteral.new(stream.next, true)
               when :token_float
                 parse_float_literal(stream)
               when :token_function
                 parse_function_expression(stream)
               when :token_int
                 parse_integer_literal(stream)
               when :token_null
                 NullLiteral.new(stream.next, nil)
               when :token_root
                 parse_root_query(stream)
               when :token_current
                 parse_relative_query(stream)
               else
                 arg_token = stream.next
                 raise JSONPathSyntaxError.new("unexpected '#{arg_token.value}'", arg_token)
               end

        expr = parse_infix_expression(stream, expr) while BINARY_OPERATORS.key? stream.peek.type

        args << expr

        if stream.peek.type != :token_rparen
          stream.expect(:token_comma)
          stream.next
        end
      end

      stream.expect(:token_rparen)
      stream.next

      validate_function_extension_signature(token, args)
      FunctionExpression.new(token, token.value, args)
    end

    def parse_grouped_expression(stream)
      stream.next # discard "("
      expr = parse_filter_expression(stream)

      while stream.peek.type != :token_rparen
        raise JSONPathSyntaxError.new("unbalanced parentheses", stream.peek) if stream.peek.type == :token_eoi

        expr = parse_infix_expression(stream, expr)
      end

      stream.expect(:token_rparen)
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

    def parse_infix_expression(stream, left)
      token = stream.next
      precedence = PRECEDENCES.fetch(token.type, Precedence::LOWEST)
      right = parse_filter_expression(stream, precedence)

      if COMPARISON_OPERATORS.member? token.value
        raise_for_non_comparable_function(left)
        raise_for_non_comparable_function(right)
        case token.type
        when :token_eq
          EqExpression.new(token, left, right)
        when :token_ge
          GeExpression.new(token, left, right)
        when :token_gt
          GtExpression.new(token, left, right)
        when :token_le
          LeExpression.new(token, left, right)
        when :token_lt
          LtExpression.new(token, left, right)
        when :token_ne
          NeExpression.new(token, left, right)
        else
          raise JSONPathSyntaxError.new("unexpected token", token)
        end
      else
        raise_for_not_compared_literal(left)
        raise_for_not_compared_literal(right)
        case token.type
        when :token_and
          LogicalAndExpression.new(token, left, right)
        when :token_or
          LogicalOrExpression.new(token, left, right)
        else
          raise JSONPathSyntaxError.new("unexpected token", token)
        end
      end
    end

    def parse_i_json_int(token)
      value = token.value

      if value.length > 1 && value.start_with?("0", "-0")
        raise JSONPathSyntaxError.new("invalid index '#{value}'", token)
      end

      begin
        int = Integer(value)
      rescue ArgumentError
        raise JSONPathSyntaxError.new("invalid I-JSON integer", token)
      end

      if int < @env.class::MIN_INT_INDEX || int > @env.class::MAX_INT_INDEX
        raise JSONPathSyntaxError.new("index out of range",
                                      token)
      end

      int
    end

    def decode_string_literal(token)
      if token.type == :token_single_quote_string
        JSONP3.unescape_string(token.value, "'", token)
      else
        JSONP3.unescape_string(token.value, '"', token)
      end
    end

    def raise_for_non_comparable_function(expression)
      if expression.is_a?(QueryExpression) && !expression.query.singular?
        raise JSONPathSyntaxError.new("non-singular query is not comparable", expression.token)
      end

      return unless expression.is_a?(FunctionExpression)

      func = @env.function_extensions[expression.name]
      return unless func.class::RETURN_TYPE != :value_expression

      raise JSONPathTypeError.new("result of #{expression.name}() is not comparable", expression.token)
    end

    def raise_for_not_compared_literal(expression)
      return unless expression.is_a? FilterExpressionLiteral

      raise JSONPathSyntaxError.new("expression literals must be compared",
                                    expression.token)
    end

    def validate_function_extension_signature(token, args)
      func = @env.function_extensions.fetch(token.value)
      count = func.class::ARG_TYPES.length

      unless args.length == count
        raise JSONPathTypeError.new(
          "#{token.value}() takes #{count} argument#{count == 1 ? "" : "s"} (#{args.length} given)",
          token
        )
      end

      func.class::ARG_TYPES.each_with_index do |t, i|
        arg = args[i]
        case t
        when :value_expression
          unless arg.is_a?(FilterExpressionLiteral) ||
                 (arg.is_a?(QueryExpression) && arg.query.singular?) ||
                 (function_return_type(arg) == :value_expression)
            raise JSONPathTypeError.new("#{token.value}() argument #{i} must be of ValueType", arg.token)
          end
        when :logical_expression
          unless arg.is_a?(QueryExpression) || arg.is_a?(InfixExpression)
            raise JSONPathTypeError.new("#{token.value}() argument #{i} must be of LogicalType", arg.token)
          end
        when :nodes_expression
          unless arg.is_a?(QueryExpression) || function_return_type(arg) == :nodes_expression
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
      token_and: Precedence::LOGICAL_AND,
      token_or: Precedence::LOGICAL_OR,
      token_not: Precedence::PREFIX,
      token_eq: Precedence::RELATIONAL,
      token_ge: Precedence::RELATIONAL,
      token_gt: Precedence::RELATIONAL,
      token_le: Precedence::RELATIONAL,
      token_lt: Precedence::RELATIONAL,
      token_ne: Precedence::RELATIONAL,
      token_rparen: Precedence::LOWEST
    }.freeze

    BINARY_OPERATORS = {
      token_and: "&&",
      token_or: "||",
      token_eq: "==",
      token_ge: ">=",
      token_gt: ">",
      token_le: "<=",
      token_lt: "<",
      token_ne: "!="
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
