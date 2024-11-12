# frozen_string_literal: true

require_relative "errors"

module JSONP3
  # Identify a single value in JSON-like data, as per RFC 6901.
  class JSONPointer
    RE_INT = /\A(0|[1-9][0-9]*)\z/
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

    # Return _true_ if this pointer can be resolved against _value_, even if the resolved
    # value is false or nil.
    def exist?(value)
      resolve(value) != UNDEFINED
    end

    # Return this pointer's parent as a new pointer. If this pointer points to the
    # document root, self is returned.
    def parent
      return self if @tokens.empty?

      JSONPointer.new(JSONPointer.encode((@tokens[...-1] || raise)))
    end

    # @param rel [String | RelativeJSONPointer]
    # @return [JSONPointer]
    def to(rel)
      p = rel.is_a?(String) ? RelativeJSONPointer.new(rel) : rel
      p.to(self)
    end

    def to_s
      @pointer
    end

    protected

    # @param pointer [String]
    # @return [Array<String | Integer>]
    def parse(pointer) # rubocop:disable Metrics/CyclomaticComplexity
      if pointer.length.positive? && !pointer.start_with?("/")
        raise JSONPointerSyntaxError,
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
    def get_item(value, token) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
      if value.is_a?(Array)
        if token.is_a?(String) && token.start_with?("#")
          maybe_index = token[1..]
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
      raise JSONPointerTypeError, "unsupported join part" unless other.is_a?(String)

      part = other.lstrip
      part.start_with?("/") ? JSONPointer.new(part) : JSONPointer.new(JSONPointer.encode(@tokens + _parse(part)))
    end
  end

  # A relative JSON Pointer.
  # See https://datatracker.ietf.org/doc/html/draft-hha-relative-json-pointer
  class RelativeJSONPointer
    RE_RELATIVE_POINTER = /\A(?<ORIGIN>\d+)(?<INDEX_G>(?<SIGN>[+-])(?<INDEX>\d))?(?<POINTER>.*)\z/m
    RE_INT = /\A(0|[1-9][0-9]*)\z/

    # @param rel [String]
    def initialize(rel) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      match = RE_RELATIVE_POINTER.match(rel)

      raise JSONPointerSyntaxError, "failed to parse relative pointer" if match.nil?

      @origin = parse_int(match[:ORIGIN] || raise)
      @index = 0

      if match[:INDEX_G]
        @index = parse_int(match[:INDEX] || raise)
        raise JSONPointerSyntaxError, "index offset can't be zero" if @index.zero?

        @index = -@index if match[:SIGN] == "-"
      end

      @pointer = match[:POINTER] == "#" ? "#" : JSONPointer.new(match[:POINTER] || raise)
    end

    def to_s
      sign = @index.positive? ? "+" : ""
      index = @index.zero? ? "" : "#{sign}#{@index}"
      "#{@origin}#{index}#{@pointer}"
    end

    # @param pointer [String | JSONPointer]
    # @return [JSONPointer]
    def to(pointer) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      p = pointer.is_a?(String) ? JSONPointer.new(pointer) : pointer

      raise JSONPointerIndexError, "origin (#{@origin}) exceeds root (#{p.tokens.length})" if @origin > p.tokens.length

      tokens = @origin < 1 ? p.tokens[0..] || raise : p.tokens[0...-@origin] || raise
      tokens[-1] = (tokens[-1] || raise) + @index if @index != 0 && tokens.length.positive? && tokens[-1].is_a?(Integer)

      if @pointer == "#"
        tokens[-1] = "##{tokens[-1]}"
      else
        tokens.concat(@pointer.tokens) # steep:ignore
      end

      JSONPointer.new(JSONPointer.encode(tokens))
    end

    private

    # @param token [String]
    # @return [Integer]
    def parse_int(token)
      raise JSONPointerSyntaxError, "unexpected leading zero" if token.start_with?("0") && token.length > 1
      raise JSONPointerSyntaxError, "expected an integer, found '#{token}'" unless RE_INT.match?(token)

      token.to_i
    end
  end
end
