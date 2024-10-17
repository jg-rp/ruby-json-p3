# frozen_string_literal: true

require "set"

require_relative "errors"
require_relative "filter"
require_relative "function"
require_relative "segment"
require_relative "selector"
require_relative "token"

module JSONPathRFC9535
  # Step through tokens
  class Stream
    def initialize(tokens)
      @it = tokens.to_enum
      @eoi = tokens.last
    end

    def next
      @it.next
    rescue StopIteration
      @eor
    end

    def peek
      @it.peek
    rescue StopIteration
      @eor
    end

    def expect(token_type)
      return if peek.type == token_type

      token = self.next
      raise JSONPathSyntaxError.new("expected #{token_type}, found #{token}", token)
    end

    def expect_not(token_type, message)
      return unless peek.type == token_type

      token = self.next
      raise JSONPathSyntaxError.new(message, token)
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

      raise JSONPathSyntaxError("empty segment", segment_token) if selectors.empty?

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
      when Token::INT
        stop = parse_i_json_int(stream.next)
      when Token::COLON
        stream.next # move past colon
      end

      case stream.peek.type
      when Token::INT
        step = parse_i_json_int(stream.next)
      else
        error_token = stream.next
        raise JSONPathSyntaxError("expected a slice, found '#{token.value}'", error_token)
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
      when Token::INT
        stop = parse_i_json_int(stream.next)
      when Token::COLON
        stream.next # move past colon
      end

      case stream.peek.type
      when Token::INT
        step = parse_i_json_int(stream.next)
      else
        error_token = stream.next
        raise JSONPathSyntaxError("expected a slice, found '#{token.value}'", error_token)
      end

      SliceSelector.new(@env, token, start, stop, step)
    end

    def parse_filter_selector(stream) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      token = stream.next
      expression = parse_filter_expression(stream)

      # Raise if expression must be compared.
      if expression.is_a? FunctionExpression
        func = @env.function_extensions[expression.name]
        if !func.nil? && func.RETURN_TYPE == ExpressionType::VALUE
          raise JSONPathTypeError.new("result of #{expresion.name}() must be compared", token)
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
             when Token::DOUBLE_QUOTE_STRING
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
               token = stream.next
               IntegerLiteral.new(token, parse_i_json_int(token))
             when Token::LPAREN
               parse_grouped_expression(stream)
             when Token::NOT
               parse_prefix_expression(stream)
             when Token::ROOT
               parse_root_query(stream)
             when Token::CURRENT
               parse_relative_query(stream)
             when Token::SINGLE_QUOTE_STRING
               token = stream.next
               StringLiteral.new(token, decode_string_literal(token))
             else
               token = stream.next
               raise JSONPathSyntaxError.new("unexpected '#{token.value}'", token)
             end

      loop do
        peeked = stream.peek
        if peeked.type == Token::EOI ||
           peeked.type == Token::RBRACKET ||
           PRECEDENCES.fetch(peek.type, Precedence::LOWEST) < precedence
          break
        end

        return left unless BINARY_OPERATORS.key?(peeked.type)

        left = parse_infix_expression(stream, left)
      end

      left
    end

    def parse_float_literal(stream)
      token = stream.next
      value = token.value
      if value.starts_with("0") && value.split(".").first.length > 1
        raise JSONPathSyntaxError.new("invalid float literal", token)
      end

      FloatLiteral.new(token, value.to_f)
    end

    def parse_function_expression(stream) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
      token = stream.next
      args = []

      while stream.peek.type != Token::RPAREN
        expr = case stream.peek.type
               when Token::DOUBLE_QUOTE_STRING
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
                 token = stream.next
                 IntegerLiteral.new(token, parse_i_json_int(token))
               when Token::ROOT
                 parse_root_query(stream)
               when Token::CURRENT
                 parse_relative_query(stream)
               when Token::SINGLE_QUOTE_STRING
                 token = stream.next
                 StringLiteral.new(token, decode_string_literal(token))
               else
                 token = stream.next
                 raise JSONPathSyntaxError.new("unexpected '#{stream.peek.value}'", stream.peek)
               end

        expr = parse_infix_expression(stream, expr) while BINARY_OPERATORS.key? stream.peek.type

        args << expr

        if stream.peek.type != Token::RPAREN
          stream.expect(Token::COMMA)
          stream.next
        end
      end

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

      steam.expect(Token::RPAREN)
      stream.next
      expr
    end

    def parse_prefix_expression(stream)
      token = tream.next
      LogicalNotExpression.new(token, parse_filter_expression(stream, Precedence::PREFIX))
    end

    def parse_root_query(stream)
      token = stream.next
      RootQueryExpression.new(token, JSONPath.new(@env, parse_query(stream))) # TODO: in filter?
    end

    def parse_relative_query(stream)
      token = stream.next
      RelativeQueryExpression.new(token, JSONPath.new(@env, parse_query(stream))) # TODO: in filter?
    end

    def parse_infix_expression(stream, left) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
      token = stream.next
      precedence = PRECEDENCES.fetch(token.type, Precedence::LOWEST)
      right = parse_filter_expression(stream, precedence)

      if COMPARISON_OPERATORS.key? token.value
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
        end
      else
        raise_for_uncompared_literal(left)
        raise_for_uncompared_literal(right)
        case token.type
        when Token::AND
          LogicalAndExpression.new(token, left, right)
        when Token::OR
          LogicalOrExpression.new(token, left, right)
        end
      end
    end

    def parse_i_json_int(token)
      # TODO: int check range
      # TODO: handle scientific notation
      if token.value.length > 1 && token.value.starts_with("0", "-0")
        raise JSONPathSyntaxError("invalid index '#{token.value}'", token)
      end

      token.value.to_i
    end

    def decode_string_literal(token)
      # TODO:
      token.value
    end

    def raise_for_non_comparable_function(expression) # rubocop:disable Metrics/AbcSize
      if expresion.is_a?(QueryExpression) && !expression.query.singular?
        raise JSONPathSyntaxError.new("non-singular query is not comparable", expression.token)
      end

      return unless expression.is_a?(FunctionExpression)

      func = @env.function_extensions[expression.name]
      return unless func.RETURN_TYPE != ExpressionType::VALUE

      raise JSONPathTypeError.new("result of #{expression.name}() is not comparable", expresion.token)
    end

    def raise_for_uncompared_literal(expression)
      return unless expreession.is_a? FilterExpressionLiteral

      raise JSONPathSyntaxError.new("expression literals must be compared",
                                    expression.token)
    end

    def validate_function_extension_sugnature(token, args) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      func = @env.function_extensions.fetch(token.value)

      unless args.length == func.ARG_TYPES.length
        raise JSONPathTypeError.new("#{token.value}() takes #{func.ARG_TYPES.length} arguments (#{args.length} given)",
                                    token)
      end

      func.ARG_TYPES.each_with_index do |t, i|
        arg = args[i]
        case t
        when ExpressionType.VALUE
          unless arg.is_a?(FilterExpressionLiteral) ||
                 (arg.is_a?(QueryExpression) && arg.query.singular?) ||
                 (function_return_type(arg) == ExpressionType::VALUE)
            raise JSONPathTypeError.new("#{token.value}() argument #{i} must be of ValueType", arg.token)
          end
        when ExpressionType.LOGICAL
          unless arg.is_a?(QueryExpression) || arg.is_a?(InfixExpression)
            raise JSONPathTypeError.new("#{token.value}() argument #{i} must be of LogicalType", arg.token)
          end
        when ExpressionType.NODES
          unless arg.is_a?(QueryExpression) || function_return_type(arg) == ExpressionType.NODES
            raise JSONPathTypeError.new("#{token.value}() argument #{i} must be of NodesType", arg.token)
          end
        end
      end
    rescue KeyError
      raise JSONPathNameError.new("function '#{token.value}' is not defined", token)
    end

    def function_return_type(expression)
      return nil unless expression.is_a? FunctionExpression

      @env.function_extensions[expression.name].RETURN_TYPE
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
