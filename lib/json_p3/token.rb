# frozen_string_literal: true

require_relative "errors"

module JSONP3
  # Tokens are produced by the lexer and consumed by the parser. Each token contains sub
  # string from a JSONPath expression, its location within the JSONPath expression and a
  # symbol indicating what type of token it is.
  class Token
    # @dynamic type, value, start, query, message
    attr_reader :type, :value, :start, :query, :message

    def initialize(type, value, start, query, message: nil)
      @type = type
      @value = value
      @start = start
      @query = query
      @message = message
    end

    def ==(other)
      self.class == other.class &&
        @type == other.type &&
        @value == other.value &&
        @start == other.start &&
        @query == other.query &&
        @message == other.message
    end

    alias eql? ==

    def hash
      [@type, @value].hash
    end
  end
end
