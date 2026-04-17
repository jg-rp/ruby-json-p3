# frozen_string_literal: true

module JSONP3
  # An exception raised when a JSONPathEnvironment is misconfigured.
  class JSONPathEnvironmentError < StandardError; end

  # Base class for JSONPath exceptions that happen when parsing or evaluating a query.
  class JSONPathError < StandardError
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
        col = lines[-1].length
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

  class JSONPathSyntaxError < JSONPathError; end
  class JSONPathTypeError < JSONPathError; end
  class JSONPathNameError < JSONPathError; end
  class JSONPathRecursionError < JSONPathError; end

  class JSONPointerError < StandardError; end
  class JSONPointerIndexError < JSONPointerError; end
  class JSONPointerSyntaxError < JSONPointerError; end
  class JSONPointerTypeError < JSONPointerError; end

  class JSONPatchError < StandardError; end
  class JSONPatchTestFailure < JSONPatchError; end
end
