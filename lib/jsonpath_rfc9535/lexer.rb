# frozen_string_literal: true

require_relative "errors"
require_relative "token"

module JsonpathRfc9535
  # Return an array of tokens for the JSONPath expression _query_.
  #
  # @param query [String] the JSONPath expression to tokenize.
  # @return [Array<Token>]
  def self.tokenize(query)
    lexer = Lexer.new(query)
    lexer.run
    lexer.tokens
  end

  # JSONPath query expreession lexical scanner.
  #
  # @see tokenize
  class Lexer # rubocop:disable Metrics/ClassLength
    RE_INT = /\A-?[0-9]+/
    RE_NAME = /\A[\u0080-\uFFFFa-zA-Z_][\u0080-\uFFFFa-zA-Z0-9_-]*/
    RE_WHITESPACE = /\A[ \n\r\t]+/

    # @dynamic tokens
    attr_reader :tokens

    def initialize(query)
      @filter_depth = 0
      @paren_stack = []
      @tokens = []
      @start = 0
      @pos = 0
      @query = query
      @length = query.length
      @chars = query.chars
    end

    def run
      state = :lex_root
      state = method(state).call until state.nil?
    end

    protected

    def emit(token_type)
      @tokens << Token.new(token_type, @chars[@start...@pos].join(""), Span.new(@start, @pos), @query)
      @start = @pos
    end

    def next
      return "" if @pos >= @length

      c = @chars[@pos]
      @pos += 1
      c
    end

    def ignore
      @start = @pos
    end

    def backup
      if @pos <= @start
        msg = "unexpected end of expression"
        raise JSONPathSyntaxError.new(msg, Token.new(Token::ERROR, msg, Span.new(@start, @pos), @query))
      end

      @pos -= 1
    end

    def peek
      c = self.next
      backup unless c.empty?
      c
    end

    def accept?(pattern)
      c = self.next
      return true if c.match?(pattern)

      backup unless c.empty?
      false
    end

    def accept_match?(pattern)
      match = @query[@pos..].match(pattern)
      return false if match.nil?

      group = match[0] or raise
      @pos += group.length
      true
    end

    def ignore_whitespace?
      unless @pos == @start
        msg = "you must emit or ignore before consuming whitespace (#{@query[@start...@pos]})"
        raise JSONPathError.new(msg, Token.new(Token::ERROR, msg, Span.new(@start, @pos), @query))
      end

      if accept_match?(RE_WHITESPACE)
        ignore
        return true
      end

      false
    end

    def error(message)
      @tokens << Token.new(Token::ERROR, message, Span.new(@start, @pos), @query)
    end

    def lex_root
      c = self.next

      unless c == "$"
        error "expected '$', found '#{c}'"
        return nil
      end

      emit Token::ROOT
      :lex_segment
    end

    def lex_segment # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
      if ignore_whitespace? && peek.empty?
        error "unexpected trailing whitespace"
        return nil
      end

      c = self.next

      case c
      when ""
        emit Token::EOI
        nil
      when "."
        return :lex_shorthand_selector unless peek == "."

        self.next
        emit Token::DOUBLE_DOT
        :lex_descendant_segment
      when "["
        emit Token::LBRACKET
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
        emit Token::WILD
        :lex_segment
      when "["
        emit Token::LBRACKET
        :lex_inside_bracketed_segment
      else
        backup
        if accept_match?(RE_NAME)
          emit Token::NAME
          :lex_segment
        else
          c = self.next
          error "unexpected descendant selection token '#{c}'"
          nil
        end
      end
    end

    def lex_shorthand_selector # rubocop:disable Metrics/MethodLength
      ignore # ignore dot

      if accept_match?(RE_WHITESPACE)
        error "unexpected whitespace after dot"
        return nil
      end

      if peek == "*"
        self.next
        emit Token::WILD
        return :lex_segment
      end

      if accept_match?(RE_NAME)
        emit Token::NAME
        return :lex_segment
      end

      error "unexpected shorthand selector '#{peek}'"
      nil
    end

    def lex_inside_bracketed_segment # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
      loop do # rubocop:disable Metrics/BlockLength
        ignore_whitespace?
        c = self.next

        case c
        when "]"
          emit Token::RBRACKET
          return @filter_depth.positive? ? :lex_inside_filter : :lex_segment
        when ""
          error "unclosed bracketed selection"
          return nil
        when "*"
          emit Token::WILD
        when "?"
          emit Token::FILTER
          @filter_depth += 1
          return :lex_inside_filter
        when ","
          emit Token::COMMA
        when ":"
          emit Token::COLON
        when "'"
          return :lex_single_quoted_string_inside_bracketed_segment
        when '"'
          return :lex_double_quoted_string_inside_bracketed_segment
        else
          backup
          if accept_match?(/\A-?[0-9]+/)
            # Index selector or part of a slice selector.
            emit Token::INDEX
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
          emit Token::COMMA
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
          emit Token::LPAREN
          # Are we in a function call? If so, a function argument contains parens.
          @paren_stack[-1] += 1 if @paren_stack.length.positive?
        when ")"
          emit Token::RPAREN
          # Are we closing a function call or a parenthesized expression?
          if @paren_stack.length.positive?
            if @paren_stack[-1] == 1
              @paren_stack.pop
            else
              @paren_stack[-1] -= 1
            end
          end
        when "$"
          emit Token::ROOT
          return :lex_segment
        when "@"
          emit Token::CURRENT
          return :lex_segment
        when "."
          backup
          return :lex_segment
        when "!"
          if peek == "="
            self.next
            emit Token::NE
          else
            emit Token::NOT
          end
        when "="
          if peek == "="
            self.next
            emit Token::EQ
          else
            backup
            error "unexpected filter selector token '#{c}'"
            return nil
          end
        when "<"
          if peek == "="
            self.next
            emit Token::LE
          else
            emit Token::LT
          end
        when ">"
          if peek == "="
            self.next
            emit Token::GE
          else
            emit Token::GT
          end
        else
          backup
          if accept_match?(RE_INT)
            if peek == "."
              # A float
              self.next
              unless accept_match?(RE_INT) # rubocop:disable Metrics/BlockNesting
                error "a fractional digit is required after a decimal point"
                return nil
              end

              accept_match?(/\A[eE][+-]?[0-9]+/)
              emit Token::FLOAT
            # An int, or float if exponent is negative
            elsif accept_match?(/\A[eE]-[0-9]+/)
              emit Token::FLOAT
            else
              accept_match?(/\A[eE][+-]?[0-9]+/)
              emit Token::INT
            end
          elsif accept_match?(/\A&&/)
            emit Token::AND
          elsif accept_match?(/\A\|\|/)
            emit Token::OR
          elsif accept_match?(/\Atrue/)
            emit Token::TRUE
          elsif accept_match?(/\Afalse/)
            emit Token::FALSE
          elsif accept_match?(/\Anull/)
            emit Token::NULL
          elsif accept_match?(/\A[a-z][a-z_0-9]*/)
            # Function name
            # Keep track of parentheses for this function call.
            @paren_stack << 1
            emit Token::FUNCTION
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
      def lex_string_factory(quote, state) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
        token = quote == "'" ? Token::SINGLE_QUOTE_STRING : Token::DOUBLE_QUOTE_STRING

        proc  { # rubocop:disable Metrics/BlockLength
          # @type self: Lexer
          ignore # move past openning quote

          if peek == ""
            # an empty string
            emit token
            self.next
            ignore
            return state
          end

          loop do
            head = @query[@os...@pos + 2] or raise
            c = self.next

            if ["\\\\", "\\#{quote}"].include?(head)
              self.next
              next
            end

            case c
            when ""
              error "unclosed string starting at index #{@start}"
              return nil
            when "\\" && head.match(%r{\\[bfnrtu/]}).nil?
              error "invalid escape"
              return nil
            when quote
              backup
              emit token
              self.next
              ignore # move past closing quote
              return state
            end
          end
        }
      end
    end

    define_method(:lex_double_quoted_string_inside_bracketed_segment,
                  lex_string_factory('"', :lex_inside_bracketed_segment))

    define_method(:lex_single_quoted_string_inside_bracketed_segment,
                  lex_string_factory("'", :lex_inside_bracketed_segment))

    define_method(:lex_double_quoted_string_inside_filter_expression,
                  lex_string_factory('"', :lex_inside_filter))

    define_method(:lex_single_quoted_string_inside_filter_expression,
                  lex_string_factory("'", :lex_inside_filter))
  end
end
