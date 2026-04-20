# frozen_string_literal: true

module JSONP3
  # Identify a single value in JSON-like data, as per RFC 6901.
  class Pointer
    RE_INT = /\A(0|[1-9][0-9]*)\z/
    UNDEFINED = :__undefined

    attr_reader :tokens

    def self.resolve(pointer, value, default: UNDEFINED)
      new(pointer).resolve(value, default: default)
    end

    # Encode an array of strings and integers into a JSON Pointer.
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
      @pointer = Pointer.encode(@tokens)
    end

    # Resolve this pointer against JSON-like data _value_.
    # @param value [Object]
    # @param default [Object] the value to return if this pointer can not be
    #  resolved against _value_.
    def resolve(value, default: UNDEFINED)
      item = value

      @tokens.each do |token|
        item = get_item(item, token)
        return default if item == UNDEFINED
      end

      item
    end

    # Resolve this pointer against _value_, returning the resolved object and its
    # parent object.
    #
    # @param value [Object]
    # @return [Array<Object>] an array with exactly two elements, one or both of
    #   which could be undefined.
    def resolve_with_parent(value)
      return [UNDEFINED, resolve(value)] if @tokens.empty?

      parent = value
      (@tokens[...-1] || raise).each do |token|
        parent = get_item(parent, token)
        break if parent == UNDEFINED
      end

      [parent, get_item(parent, @tokens.last)]
    end

    # Return true if this pointer is relative to _pointer_.
    # @param pointer [Pointer]
    # @return [bool]
    def relative_to?(pointer)
      pointer.tokens.length < @tokens.length && @tokens[...pointer.tokens.length] == pointer.tokens
    end

    # @param parts [String]
    # @return [Pointer]
    def join(*parts)
      pointer = self
      parts.each do |part|
        pointer = pointer._join(part)
      end
      pointer
    end

    # Return _true_ if this pointer can be resolved against _value_, even if the resolved
    # value is false or nil.
    # @param value [Object]
    def exist?(value)
      resolve(value) != UNDEFINED
    end

    # Return this pointer's parent as a new pointer. If this pointer points to the
    # document root, self is returned.
    def parent
      return self if @tokens.empty?

      Pointer.new(Pointer.encode(@tokens[...-1] || raise))
    end

    # Return a new pointer relative to this pointer using Relative JSON Pointer syntax.
    # @param rel [String | RelativePointer]
    # @return [Pointer]
    def to(rel)
      p = rel.is_a?(String) ? RelativePointer.new(rel) : rel
      p.to(self)
    end

    def to_s
      @pointer
    end

    protected

    # @param pointer [String]
    # @return [Array<String | Integer>]
    def parse(pointer)
      if pointer.length.positive? && !pointer.start_with?("/")
        raise JSONP3::Pointer::SyntaxError,
              "pointers must start with a slash or be the empty string"
      end

      return [] if pointer.empty?
      return [""] if pointer == "/"

      (pointer[1..] || raise).split("/", -1).map do |token|
        token.match?(/\A(?:0|[1-9][0-9]*)\z/) ? Integer(token) : token.gsub("~1", "/").gsub("~0", "~")
      end
    end

    # @param value [Object]
    # @param token [String | Integer]
    # @return [Object] the "fetched" object from _value_ or UNDEFINED.
    def get_item(value, token)
      if value.is_a?(Array)
        if token.is_a?(String) && token.start_with?("#")
          maybe_index = token[1..] || raise
          return maybe_index.to_i if RE_INT.match?(maybe_index)
        end

        return UNDEFINED unless token.is_a?(Integer)
        return UNDEFINED if token.negative? || token >= value.length

        value[token]
      elsif value.is_a?(Hash)
        return value[token] if value.key?(token)

        # Handle "#" from relative JSON pointer
        return token[1..] if token.is_a?(String) && token.start_with?("#") && value.key?(token[1..])

        # Token might be an integer. Force it to a string and try again.
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
        token.match?(/\A(?:0|[1-9][0-9]*)\z/) ? Integer(token) : token.gsub("~1", "/").gsub("~0", "~")
      end
    end

    def _join(other)
      raise JSONP3::Pointer::TypeError, "unsupported join part" unless other.is_a?(String)

      part = other.lstrip
      part.start_with?("/") ? Pointer.new(part) : Pointer.new(Pointer.encode(@tokens + _parse(part)))
    end
  end
end
