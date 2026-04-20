# frozen_string_literal: true

require "json"

require_relative "filter"
require_relative "function"
require_relative "segment"
require_relative "selector"
require_relative "unescape"

module JSONP3
  # JSONPath query expressions.
  module Path
    # JSONPath query parser.
    class Parser
      class Precedence
        LOWEST = 1
        LOGICAL_OR = 3
        LOGICAL_AND = 4
        RELATIONAL = 5
        PREFIX = 7
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
        :token_eq,
        :token_ge,
        :token_gt,
        :token_le,
        :token_lt,
        :token_ne
      ]

      # @param env [JSONPathEnvironment]
      # @param query [String]
      # @param tokens [Array[t_token]]
      def initialize(env, query, tokens)
        @env = env
        @query = query
        @tokens = tokens
        @pos = 0
        @eoi = [:token_eoi, query.size, query.size] #: t_token
      end

      def next
        if (token = @tokens[@pos])
          @pos += 1
          token
        else
          @eoi
        end
      end

      def eat(kind, message = nil)
        token = self.next
        unless token.first == kind
          raise SyntaxError.new(
            message || "expected #{kind}, found #{token.first}",
            token,
            @query
          )
        end

        token
      end

      def skip(kind)
        @pos += 1 if (@tokens[@pos] || @eoi).first == kind
      end

      def kind = (@tokens[@pos] || @eoi).first
      def peek = @tokens[@pos] || @eoi

      def parse
        eat(:token_dollar)
        segments = parse_segments
        eat(:token_eoi)
        segments
      end

      def parse_segments
        segments = [] #: Array[Segment]

        loop do
          case peek.first
          when :token_trivia
            @pos += 1
            if peek.first == :token_eoi
              raise SyntaxError.new(
                "unexpected trailing whitespace",
                @tokens[@pos - 1],
                @query
              )
            end
          when :token_double_dot
            segments << DescendantSegment.new(
              @env,
              self.next,
              parse_descendant_selectors
            )
          when :token_dot
            segments << ChildSegment.new(
              @env,
              self.next,
              [parse_shorthand_selector]
            )
          when :token_lbracket
            segments << ChildSegment.new(
              @env,
              peek,
              parse_bracketed_selectors
            )
          else
            break
          end
        end

        segments
      end

      def parse_descendant_selectors
        case peek.first
        when :token_name, :token_asterisk
          [parse_shorthand_selector]
        when :token_lbracket
          parse_bracketed_selectors
        else
          raise SyntaxError.new(
            "expected a selector",
            peek,
            @query
          )
        end
      end

      def parse_shorthand_selector
        token = self.next

        case token.first
        when :token_name
          @env.class::NAME_SELECTOR.new(
            @env,
            token,
            JSONP3::Path.get_token_value(token, @query)
          )
        when :token_asterisk
          WildcardSelector.new(@env, token)
        else
          raise SyntaxError.new(
            "expected a shorthand selector",
            token,
            @query
          )
        end
      end

      def parse_bracketed_selectors
        segment_token = eat(:token_lbracket)
        selectors = [] #: Array[Selector]

        loop do
          skip(:token_trivia)

          case peek.first
          when :token_rbracket
            break
          when :token_index
            selectors << parse_index_or_slice
          when :token_double_quoted_string, :token_single_quoted_string
            token = self.next
            selectors << @env.class::NAME_SELECTOR.new(
              @env,
              token,
              JSONP3::Path.get_token_value(token, @query)
            )
          when :token_double_quoted_esc_string, :token_single_quoted_esc_string
            token = self.next
            selectors << @env.class::NAME_SELECTOR.new(
              @env,
              token,
              JSONP3::Path.unescape(
                JSONP3::Path.get_token_value(token, @query), token, @query
              )
            )
          when :token_colon
            selectors << parse_slice_selector
          when :token_asterisk
            selectors << WildcardSelector.new(@env, self.next)
          when :token_question
            selectors << parse_filter_selector
          when :token_eoi
            raise SyntaxError.new(
              "unexpected end of query",
              peek,
              @query
            )
          else
            raise SyntaxError.new(
              "unexpected token #{JSONP3::Path.get_token_value(peek, @query).inspect}",
              self.next,
              @query
            )
          end

          skip(:token_trivia)

          case peek.first
          when :token_eoi
            raise SyntaxError.new(
              "unexpected end of query",
              peek,
              @query
            )
          when :token_rbracket
            break
          else
            eat(:token_comma)
            if peek.first == :token_rbracket
              raise SyntaxError.new(
                "unexpected trailing comma",
                peek,
                @query
              )
            end
          end
        end

        skip(:token_trivia)
        eat(:token_rbracket)

        if selectors.empty?
          raise SyntaxError.new(
            "unexpected empty segment",
            segment_token,
            @query
          )
        end

        selectors
      end

      def parse_index_or_slice
        token = self.next
        index = parse_i_json_int(token)
        skip(:token_trivia)

        return @env.class::INDEX_SELECTOR.new(@env, token, index) unless peek.first == :token_colon

        stop = nil
        step = nil

        eat(:token_colon)
        skip(:token_trivia)

        if peek.first == :token_index
          stop = parse_i_json_int(self.next)
          skip(:token_trivia)
        end

        if peek.first == :token_colon
          self.next
          skip(:token_trivia)
          step = parse_i_json_int(self.next) if peek.first == :token_index
        end

        SliceSelector.new(@env, token, index, stop, step)
      end

      def parse_slice_selector
        token = eat(:token_colon)
        skip(:token_trivia)

        stop = nil
        step = nil

        if peek.first == :token_index
          stop = parse_i_json_int(self.next)
          skip(:token_trivia)
        end

        if peek.first == :token_colon
          self.next
          skip(:token_trivia)
          step = parse_i_json_int(self.next) if peek.first == :token_index
        end

        SliceSelector.new(@env, token, nil, stop, step)
      end

      def parse_filter_selector
        token = eat(:token_question)
        expr = parse_filter_expression(Precedence::LOWEST)
        throw_for_not_compared(expr)
        FilterSelector.new(@env, token, FilterExpression.new(token, expr))
      end

      def parse_filter_expression(precedence)
        left = parse_primary

        loop do
          skip(:token_trivia)
          kind = peek.first

          if kind == :token_eoi ||
             kind == :token_rbracket ||
             !BINARY_OPERATORS.include?(kind) ||
             PRECEDENCES.fetch(kind, Precedence::LOWEST) < precedence
            break
          end

          left = parse_infix_expression(left)
        end

        left
      end

      def parse_function_expression
        token = eat(:token_name)
        eat(:token_lparen)

        args = [] #: Array[Expression]

        while peek.first != :token_rparen
          expr = parse_primary
          skip(:token_trivia)

          expr = parse_infix_expression(expr) while BINARY_OPERATORS.include?(peek.first)
          args << expr

          if peek.first != :token_rparen
            skip(:token_trivia)
            eat(:token_comma)
          end

        end

        skip(:token_trivia)
        eat(:token_rparen)

        name = JSONP3::Path.get_token_value(token, @query)
        func = @env.function_extensions[name]

        unless func
          raise JSONPathNameError.new(
            "unknown function extension #{name}",
            token,
            @query
          )
        end

        validate_function_signature(name, func, args, token)

        FunctionExpression.new(
          token,
          name,
          func,
          args
        )
      end

      def parse_primary
        skip(:token_trivia)
        peeked = peek

        case peeked.first
        when :token_single_quoted_string, :token_double_quoted_string
          token = self.next
          StringLiteral.new(token, JSONP3::Path.get_token_value(token, @query))
        when :token_single_quoted_esc_string, :token_double_quoted_esc_string
          token = self.next
          StringLiteral.new(
            token,
            JSONP3::Path.unescape(
              JSONP3::Path.get_token_value(token, @query), token, @query
            )
          )
        when :token_name
          case JSONP3::Path.get_token_value(peeked, @query)
          when "null"
            NullLiteral.new(self.next, nil)
          when "false"
            BooleanLiteral.new(self.next, false)
          when "true"
            BooleanLiteral.new(self.next, true)
          else
            parse_function_expression
          end
        when :token_lparen
          parse_grouped_expression
        when :token_index, :token_int
          parse_integer_literal
        when :token_float
          parse_float_literal
        when :token_dollar
          parse_absolute_query
        when :token_at
          parse_relative_query
        when :token_not
          parse_prefix_expression
        else
          raise SyntaxError.new(
            "unexpected token #{peek.first}",
            self.next,
            @query
          )
        end
      end

      def parse_grouped_expression
        eat(:token_lparen)
        expr = parse_filter_expression(Precedence::LOWEST)

        loop do
          skip(:token_trivia)
          peeked = peek

          break if peeked.first == :token_rparen

          if peeked.first == :token_eoi
            raise SyntaxError.new(
              "unbalanced parentheses",
              peeked,
              @query
            )
          end

          expr = parse_infix_expression(expr)
        end

        skip(:token_trivia)
        eat(:token_rparen)
        expr
      end

      def parse_prefix_expression
        token = eat(:token_not)
        LogicalNotExpression.new(
          token,
          parse_filter_expression(Precedence::PREFIX)
        )
      end

      def parse_infix_expression(left)
        token = self.next
        kind = token.first
        precedence = PRECEDENCES[kind] || Precedence::LOWEST
        right = parse_filter_expression(precedence)

        if COMPARISON_OPERATORS.include?(kind)
          throw_for_non_comparable(left)
          throw_for_non_comparable(right)

          case kind
          when :token_eq
            EqExpression.new(token, left, right)
          when :token_ne
            NeExpression.new(token, left, right)
          when :token_lt
            LtExpression.new(token, left, right)
          when :token_le
            LeExpression.new(token, left, right)
          when :token_gt
            GtExpression.new(token, left, right)
          when :token_ge
            GeExpression.new(token, left, right)
          else
            raise SyntaxError.new(
              "expected an infix operator",
              token,
              @query
            )
          end
        else
          throw_for_not_compared(left)
          throw_for_not_compared(right)

          case kind
          when :token_and
            LogicalAndExpression.new(token, left, right)
          when :token_or
            LogicalOrExpression.new(token, left, right)
          else
            raise SyntaxError.new(
              "expected an infix operator",
              token,
              @query
            )
          end
        end
      end

      def parse_integer_literal
        token = self.next
        value = JSONP3::Path.get_token_value(token, @query)

        if value.start_with?("0") && value.length > 1
          raise SyntaxError.new(
            "invalid integer literal",
            token,
            @query
          )
        end

        IntegerLiteral.new(token, Integer(Float(value)))
      end

      def parse_float_literal
        token = self.next
        value = JSONP3::Path.get_token_value(token, @query)

        if value.start_with?("0") && value.split(".").first.length > 1
          raise SyntaxError.new(
            "invalid float literal",
            token,
            @query
          )
        end

        FloatLiteral.new(token, Float(value))
      end

      def parse_absolute_query
        token = eat(:token_dollar)
        AbsoluteQueryExpression.new(token, Query.new(@env, parse_segments))
      end

      def parse_relative_query
        token = eat(:token_at)
        RelativeQueryExpression.new(token, Query.new(@env, parse_segments))
      end

      def parse_i_json_int(token)
        value = JSONP3::Path.get_token_value(token, @query)

        if value.length > 1 && value.start_with?("0", "-0")
          raise SyntaxError.new(
            "invalid index '#{value}'",
            token,
            @query
          )
        end

        begin
          int = Integer(value)
        rescue ArgumentError
          raise SyntaxError.new(
            "invalid I-JSON integer",
            token,
            @query
          )
        end

        if int < @env.class::MIN_INT_INDEX || int > @env.class::MAX_INT_INDEX
          raise SyntaxError.new(
            "index out of range",
            token,
            @query
          )
        end

        int
      end

      def throw_for_not_compared(expression)
        if expression.is_a?(FilterExpressionLiteral)
          raise TypeError.new(
            "filter expression literals must be compared",
            expression.token,
            @query
          )
        end

        if expression.is_a?(FunctionExpression) &&
           expression.func.class::RETURN_TYPE == :value_expression
          raise TypeError.new(
            "result of #{expression.name}() must be compared",
            expression.token,
            @query
          )
        end
      end

      def throw_for_non_comparable(expression)
        if expression.is_a?(QueryExpression) && !expression.query.singular?
          raise TypeError.new(
            "non-singular query is not comparable",
            expression.token,
            @query
          )
        end

        if expression.is_a?(FunctionExpression) &&
           expression.func.class::RETURN_TYPE != :value_expression
          raise TypeError.new(
            "result of #{expression.name}() is not comparable",
            expression.token,
            @query
          )
        end
      end

      def validate_function_signature(name, func, args, token)
        count = func.class::ARG_TYPES.length

        unless args.length == count
          raise TypeError.new(
            "#{name}() takes #{count} argument#{"s" unless count == 1} (#{args.length} given)",
            token,
            @query
          )
        end

        func.class::ARG_TYPES.each_with_index do |t, i|
          arg = args[i]
          case t
          when :value_expression
            unless arg.is_a?(FilterExpressionLiteral) ||
                   (arg.is_a?(QueryExpression) && arg.query.singular?) ||
                   (function_return_type(arg) == :value_expression)
              raise TypeError.new(
                "#{name}() argument #{i} must be of ValueType",
                arg.token,
                @query
              )
            end
          when :logical_expression
            unless arg.is_a?(QueryExpression) || arg.is_a?(InfixExpression)
              raise TypeError.new(
                "#{name}() argument #{i} must be of LogicalType",
                arg.token,
                @query
              )
            end
          when :nodes_expression
            unless arg.is_a?(QueryExpression) || function_return_type(arg) == :nodes_expression
              raise TypeError.new(
                "#{name}() argument #{i} must be of NodesType",
                arg.token,
                @query
              )
            end
          end
        end
      end

      def function_return_type(expression)
        return nil unless expression.is_a? FunctionExpression

        expression.func.class::RETURN_TYPE
      end
    end
  end
end
