# frozen_string_literal: true

require "set"
require "strscan"
require_relative "errors"
require_relative "token"

module JSONP3 # rubocop:disable Style/Documentation
  # Return an array of tokens for the JSONPath expression _query_.
  #
  # @param query [String] the JSONPath expression to tokenize.
  # @return [Array<Token>]
  def self.tokenize(query)
    lexer = Lexer.new(query)
    lexer.run
    tokens = lexer.tokens

    if !tokens.empty? && tokens.last.type == :token_error
      raise JSONPathSyntaxError.new(tokens.last.message || raise,
                                    tokens.last)
    end

    tokens
  end

  # JSONPath query expression lexical scanner.
  #
  # @see tokenize
  class Lexer # rubocop:disable Metrics/ClassLength
    RE_INT = /-?[0-9]+/
    RE_NAME = /[\u0080-\uFFFFa-zA-Z_][\u0080-\uFFFFa-zA-Z0-9_-]*/
    RE_WHITESPACE = /[ \n\r\t]+/
    S_ESCAPES = Set["b", "f", "n", "r", "t", "u", "/", "\\"].freeze

    # @dynamic tokens
    attr_reader :tokens

    def initialize(query)
      @filter_depth = 0
      @paren_stack = []
      @tokens = []
      @start = 0
      @query = query.freeze
      @scanner = StringScanner.new(query)
    end

    def run
      state = :lex_root
      state = send(state) until state.nil?
    end

    protected

    # Generate a new token with the given type.
    # @param token_type [Symbol] one of the constants defined on the _Token_ class.
    # @param value [String | nil] a the token's value, if it is known, otherwise the
    #   value will be sliced from @query. This is a performance optimization.
    def emit(token_type, value = nil)
      @tokens << Token.new(token_type, value || @query[@start, @scanner.charpos - @start], @start, @query)
      @start = @scanner.charpos
    end

    def next
      @scanner.get_byte || ""
    end

    def ignore
      @start = @scanner.charpos
    end

    def backup
      @scanner.pos -= 1
    end

    def peek
      # Assumes we're peeking single byte characters.
      @scanner.peek(1)
    end

    # Advance the lexer if _pattern_ matches from the current position.
    def accept?(pattern)
      !@scanner.scan(pattern).nil?
    end

    # Accept a run of digits, possibly preceded by a negative sign.
    # Does not handle exponents.
    def accept_int?
      !@scanner.scan(RE_INT).nil?
    end

    def ignore_whitespace?
      if @scanner.scan(RE_WHITESPACE).nil?
        false
      else
        ignore
        true
      end
    end

    def error(message)
      @tokens << Token.new(
        :token_error, @query[@start, @scanner.charpos - @start] || "", @start, @query, message: message
      )
    end

    def lex_root
      c = self.next

      unless c == "$"
        error "expected '$', found '#{c}'"
        return nil
      end

      emit(:token_root, "$")
      :lex_segment
    end

    def lex_segment # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
      if accept?(RE_WHITESPACE) && peek.empty?
        error "unexpected trailing whitespace"
        return nil
      end

      ignore
      c = self.next

      case c
      when ""
        emit(:token_eoi, "")
        nil
      when "."
        return :lex_shorthand_selector unless peek == "."

        self.next
        emit(:token_double_dot, "..")
        :lex_descendant_segment
      when "["
        emit(:token_lbracket, "[")
        :lex_inside_bracketed_segment
      else
        if @filter_depth.positive?
          backup
          :lex_inside_filter
        else
          error "expected '.', '..' or a bracketed selection, found '#{c}'"
          nil
        end
      end
    end

    def lex_descendant_segment # rubocop:disable Metrics/MethodLength
      case self.next
      when ""
        error "bald descendant segment"
        nil
      when "*"
        emit(:token_wild, "*")
        :lex_segment
      when "["
        emit(:token_lbracket, "[")
        :lex_inside_bracketed_segment
      else
        backup
        if accept?(RE_NAME)
          emit(:token_name)
          :lex_segment
        else
          c = self.next
          error "unexpected descendant selection token '#{c}'"
          nil
        end
      end
    end

    def lex_shorthand_selector # rubocop:disable Metrics/MethodLength
      if peek == ""
        error "unexpected trailing dot"
        return nil
      end

      ignore # ignore dot

      if accept?(RE_WHITESPACE)
        error "unexpected whitespace after dot"
        return nil
      end

      if peek == "*"
        self.next
        emit(:token_wild, "*")
        return :lex_segment
      end

      if accept?(RE_NAME)
        emit(:token_name)
        return :lex_segment
      end

      c = self.next
      error "unexpected shorthand selector '#{c}'"
      nil
    end

    def lex_inside_bracketed_segment # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
      loop do # rubocop:disable Metrics/BlockLength
        ignore_whitespace?
        c = self.next

        case c
        when "]"
          emit(:token_rbracket, "]")
          return @filter_depth.positive? ? :lex_inside_filter : :lex_segment
        when ""
          error "unclosed bracketed selection"
          return nil
        when "*"
          emit(:token_wild, "*")
        when "?"
          emit(:token_filter, "?")
          @filter_depth += 1
          return :lex_inside_filter
        when ","
          emit(:token_comma, ",")
        when ":"
          emit(:token_colon, ":")
        when "'"
          return :lex_single_quoted_string_inside_bracketed_segment
        when '"'
          return :lex_double_quoted_string_inside_bracketed_segment
        else
          backup
          if accept_int?
            # Index selector or part of a slice selector.
            emit(:token_index)
          else
            error "unexpected token '#{c}' in bracketed selection"
            return nil
          end
        end
      end
    end

    def lex_inside_filter # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      loop do # rubocop:disable Metrics/BlockLength
        ignore_whitespace?
        c = self.next

        case c
        when ""
          error "unclosed bracketed selection"
          return nil
        when "]"
          @filter_depth -= 1
          if @paren_stack.length == 1
            error "unbalanced parentheses"
            return nil
          end
          backup
          return :lex_inside_bracketed_segment
        when ","
          emit(:token_comma, ",")
          # If we have unbalanced parens, we are inside a function call and a
          # comma separates arguments. Otherwise a comma separates selectors.
          next if @paren_stack.length.positive?

          @filter_depth -= 1
          return :lex_inside_bracketed_segment
        when "'"
          return :lex_single_quoted_string_inside_filter_expression
        when '"'
          return :lex_double_quoted_string_inside_filter_expression
        when "("
          emit(:token_lparen, "(")
          # Are we in a function call? If so, a function argument contains parens.
          @paren_stack[-1] += 1 if @paren_stack.length.positive?
        when ")"
          emit(:token_rparen, ")")
          # Are we closing a function call or a parenthesized expression?
          if @paren_stack.length.positive?
            if @paren_stack[-1] == 1
              @paren_stack.pop
            else
              @paren_stack[-1] -= 1
            end
          end
        when "$"
          emit(:token_root, "$")
          return :lex_segment
        when "@"
          emit(:token_current, "@")
          return :lex_segment
        when "."
          backup
          return :lex_segment
        when "!"
          if peek == "="
            self.next
            emit(:token_ne, "!=")
          else
            emit(:token_not, "!")
          end
        when "="
          if peek == "="
            self.next
            emit(:token_eq, "==")
          else
            backup
            error "found '=', did you mean '==', '!=', '<=' or '>='?"
            return nil
          end
        when "<"
          if peek == "="
            self.next
            emit(:token_le, "<=")
          else
            emit(:token_lt, "<")
          end
        when ">"
          if peek == "="
            self.next
            emit(:token_ge, ">=")
          else
            emit(:token_gt, ">")
          end
        else
          backup
          if accept_int?
            if peek == "."
              # A float
              self.next
              unless accept_int? # rubocop:disable Metrics/BlockNesting
                error "a fractional digit is required after a decimal point"
                return nil
              end

              accept?(/[eE][+-]?[0-9]+/)
              emit :token_float
            # An int, or float if exponent is negative
            elsif accept?(/[eE]-[0-9]+/)
              emit :token_float
            else
              accept?(/[eE][+-]?[0-9]+/)
              emit :token_int
            end
          elsif accept?("&&")
            emit(:token_and, "&&")
          elsif accept?("||")
            emit(:token_or, "||")
          elsif accept?("true")
            emit(:token_true, "true")
          elsif accept?("false")
            emit(:token_false, "false")
          elsif accept?("null")
            emit(:token_null, "null")
          elsif accept?(/[a-z][a-z_0-9]*/)
            unless peek == "("
              error "unexpected filter selector token"
              return nil
            end
            # Function name
            # Keep track of parentheses for this function call.
            @paren_stack << 1
            emit :token_function
            self.next
            ignore # move past LPAREN
          else
            error "unexpected filter selector token '#{c}'"
            return nil
          end
        end
      end
    end

    class << self
      def lex_string_factory(quote, state, token) # rubocop:disable Metrics/MethodLength
        proc {
          # @type self: Lexer
          ignore # move past opening quote

          loop do
            c = self.next

            case c
            when ""
              error "unclosed string starting at index #{@start}"
              return nil
            when "\\"
              peeked = peek
              if S_ESCAPES.member?(peeked) || peeked == quote
                self.next
              else
                error "invalid escape"
                return nil
              end
            when quote
              backup
              emit(token)
              self.next
              ignore # move past closing quote
              return state
            end
          end
        }
      end
    end

    define_method(:lex_double_quoted_string_inside_bracketed_segment,
                  lex_string_factory('"', :lex_inside_bracketed_segment, :token_double_quote_string))

    define_method(:lex_single_quoted_string_inside_bracketed_segment,
                  lex_string_factory("'", :lex_inside_bracketed_segment, :token_single_quote_string))

    define_method(:lex_double_quoted_string_inside_filter_expression,
                  lex_string_factory('"', :lex_inside_filter, :token_double_quote_string))

    define_method(:lex_single_quoted_string_inside_filter_expression,
                  lex_string_factory("'", :lex_inside_filter, :token_single_quote_string))
  end
end
