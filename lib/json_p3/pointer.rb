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
    def resolve(value, fallback: UNDEFINED) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize
      item = value

      @tokens.each_with_index do |token, index|
        next_item = get_item(item, token)
        case next_item
        when :index_out_of_range
          return fallback if fallback != UNDEFINED

          raise JSONPointerIndexError, "index out of range '#{JSONPointer.encode(@tokens[..index])}'"
        when :no_such_property
          return fallback if fallback != UNDEFINED

          raise JSONPointerKeyError, "no such key '#{JSONPointer.encode(@tokens[..index])}'"
        when :index_token_type_error
          return fallback if fallback != UNDEFINED

          raise JSONPointerTypeError,
                "no implicit conversion from #{token.class} to array index '#{JSONPointer.encode(@tokens[..index])}'"
        when :value_type_error
          return fallback if fallback != UNDEFINED

          raise JSONPointerTypeError,
                "expected an array or hash, found #{value.class} '#{JSONPointer.encode(@tokens[..index])}'"
        else
          item = next_item
        end
      end

      item
    end

    # TODO: resolve_with_parent
    # TODO: is_relative_to / relative_to?
    # TODO: join
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

      (pointer[1..] || raise).split("/", -1).map do |token|
        token.match?(/\A[1-9][0-9]*\z/) ? Integer(token) : token.gsub("~1", "/").gsub("~0", "~")
      end
    end

    # @param value [Object]
    # @param token [String | Integer]
    # @return [Object] the "fetched" object from _value_ or a symbol indicating
    #   why an object could not be selected using _token_.
    def get_item(value, token) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      if value.is_a?(Array)
        # TODO: handle "#" from relative JSON pointer
        return :index_token_type_error unless token.is_a?(Integer)
        return :index_out_of_range if token.negative? || token >= value.length

        value[token]
      elsif value.is_a?(Hash)
        # TODO: handle "#" from relative JSON pointer
        return value[token] if value.key?(token)

        string_token = token.to_s
        value.key?(string_token) ? value[string_token] : :no_such_property
      else
        :value_type_error
      end
    end
  end
end
