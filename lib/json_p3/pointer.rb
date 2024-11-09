# frozen_string_literal: true

require_relative "errors"

module JSONP3
  # Identify a single value in JSON-like data, as per RFC 6901.
  class JSONPointer
    UNDEFINED = :__undefined

    attr_reader :tokens

    # Encode an array of strings and integers into a JSON pointer.
    # @param tokens [Array<String | Integer> | nil]
    # @return [String]
    def self.encode(tokens)
      return "" if tokens.nil? || tokens.empty?

      encoded = tokens.map do |token|
        token.is_a?(Integer) ? token.to_s : token.gsub("~", "~0").gsub("/", "~1")
      end

      "/#{encoded.join("/")}"
    end

    # @param pointer [String]
    def initialize(pointer)
      @tokens = parse(pointer)
      @pointer = JSONPointer.encode(@tokens)
    end

    # Resolve this pointer against JSON-like data _value_.
    def resolve(value, default: UNDEFINED)
      item = value

      @tokens.each do |token|
        item = get_item(item, token)
        return default if item == UNDEFINED
      end

      item
    end

    def resolve_with_parent(value)
      return [UNDEFINED, resolve(value)] if @tokens.empty?

      parent = value
      (@tokens[...-1] || raise).each do |token|
        parent = get_item(parent, token)
        break if parent == UNDEFINED
      end

      [parent, get_item(parent, @tokens.last)]
    end

    def relative_to?(pointer)
      pointer.tokens.length < @tokens.length && @tokens[...pointer.tokens.length] == pointer.tokens
    end

    # @param parts [String]
    def join(*parts)
      pointer = self
      parts.each do |part|
        pointer = pointer._join(part)
      end
      pointer
    end

    # TODO: exists / include
    # TODO: parent
    # TODO: to

    def to_s
      @pointer
    end

    protected

    # @param pointer [String]
    # @return [Array<String | Integer>]
    def parse(pointer)
      if pointer.length.positive? && !pointer.start_with?("/")
        raise JSONPointerSyntaxError,
              "pointers must start with a slash or be the empty string"
      end

      return [] if pointer.empty?

      (pointer[1..] || raise).split("/", -1).map do |token|
        token.match?(/\A[1-9][0-9]*\z/) ? Integer(token) : token.gsub("~1", "/").gsub("~0", "~")
      end
    end

    # @param value [Object]
    # @param token [String | Integer]
    # @return [Object] the "fetched" object from _value_ or UNDEFINED.
    def get_item(value, token) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      if value.is_a?(Array)
        # TODO: handle "#" from relative JSON pointer
        return UNDEFINED unless token.is_a?(Integer)
        return UNDEFINED if token.negative? || token >= value.length

        value[token]
      elsif value.is_a?(Hash)
        # TODO: handle "#" from relative JSON pointer
        return value[token] if value.key?(token)

        string_token = token.to_s
        value.key?(string_token) ? value[string_token] : UNDEFINED
      else
        UNDEFINED
      end
    end

    # Like `#parse`, but assumes there's no leading slash.
    # @param pointer [String]
    # @return [Array<String | Integer>]
    def _parse(pointer)
      return [] if pointer.empty?

      pointer.split("/", -1).map do |token|
        token.match?(/\A[1-9][0-9]*\z/) ? Integer(token) : token.gsub("~1", "/").gsub("~0", "~")
      end
    end

    def _join(other)
      raise JSONPointerTypeError, "unsupported join part" unless other.is_a?(String)

      part = other.lstrip
      part.start_with?("/") ? JSONPointer.new(part) : JSONPointer.new(JSONPointer.encode(@tokens + _parse(part)))
    end
  end
end
