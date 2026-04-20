# frozen_string_literal: true

module JSONP3
  # Base class for all errors raised from this gem.
  class Error < StandardError; end

  module Path
    # Base class for all JSONPath errors.
    class Error < JSONP3::Error
      FULL_MESSAGE = ((RUBY_VERSION.split(".")&.map(&:to_i) <=> [3, 2, 0]) || -1) < 1

      def initialize(msg, token, query)
        super(msg)
        @token = token
        @query = query
      end

      def detailed_message(highlight: true, **_kwargs)
        if @query.strip.empty?
          "empty query"
        else
          value = JSONP3::Path.get_token_value(@token, @query)
          lines = @query[...@token[1]]&.lines or [""] # pleasing the type checker
          lineno = lines.length
          col = lines.last.length
          pad = " " * lineno.to_s.length
          pointer = (" " * col) + ("^" * [value.length, 1].max)
          <<~ENDOFMESSAGE.strip
            #{self.class}: #{message}
            #{pad} -> '#{@query}' #{lineno}:#{col}
            #{pad} |
            #{lineno} | #{@query}
            #{pad} | #{pointer} #{highlight ? "\e[1m#{message}\e[0m" : message}
          ENDOFMESSAGE
        end
      end

      def full_message(highlight: true, order: :top)
        if FULL_MESSAGE
          # For Ruby < 3.2.0
          "#{super}\n#{detailed_message(highlight: highlight, order: order)}"
        else
          super
        end
      end
    end

    class SyntaxError < Error; end
    class TypeError < Error; end
    class NameError < Error; end
    class RecursionError < Error; end
  end

  class Pointer
    class Error < JSONP3::Error; end
    class IndexError < Error; end
    class SyntaxError < Error; end
    class TypeError < Error; end
  end

  class Patch
    class Error < JSONP3::Error; end
    class TestFailure < Error; end
  end
end
