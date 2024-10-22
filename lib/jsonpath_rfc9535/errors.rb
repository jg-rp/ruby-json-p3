# frozen_string_literal: true

module JSONPathRFC9535
  # Base class for all JSONPath exceptions
  class JSONPathError < StandardError
    def initialize(msg, token)
      super(msg)
      @token = token
    end

    def detailed_message(highlight: true, **_kwargs) # rubocop:disable Metrics/AbcSize
      if @token.query.strip.empty?
        "empty query"
      else
        lines = @token.query[...@token.start]&.lines or [""] # pleasing the type checker
        lineno = lines.length
        col = lines[-1].length
        pad = " " * lineno.to_s.length
        pointer = (" " * col) + ("^" * [@token.value.length, 1].max)
        <<~ENDOFMESSAGE.strip
          #{self.class}: #{message}
          #{pad} -> '#{@token.query}' #{lineno}:#{col}
          #{pad} |
          #{lineno} | #{@token.query}
          #{pad} | #{pointer} #{highlight ? "\e[1m#{message}\e[0m" : message}
        ENDOFMESSAGE
      end
    end

    def full_message(highlight: true, order: :top)
      "#{super}\n#{detailed_message(highlight: highlight, order: order)}"
    end
  end

  class JSONPathSyntaxError < JSONPathError; end
  class JSONPathTypeError < JSONPathError; end
  class JSONPathNameError < JSONPathError; end
  class JSONPathRecursionError < JSONPathError; end
end
