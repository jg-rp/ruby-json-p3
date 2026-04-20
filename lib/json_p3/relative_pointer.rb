# frozen_string_literal: true

module JSONP3
  # A relative JSON Pointer.
  # See https://datatracker.ietf.org/doc/html/draft-hha-relative-json-pointer
  class RelativePointer
    RE_RELATIVE_POINTER = /\A(?<ORIGIN>\d+)(?<INDEX_G>(?<SIGN>[+-])(?<INDEX>\d))?(?<POINTER>.*)\z/m
    RE_INT = /\A(0|[1-9][0-9]*)\z/

    # @param rel [String]
    def initialize(rel)
      match = RE_RELATIVE_POINTER.match(rel)

      raise JSONP3::Pointer::SyntaxError, "failed to parse relative pointer" if match.nil?

      @origin = parse_int(match[:ORIGIN] || raise)
      @index = 0

      if match[:INDEX_G]
        @index = parse_int(match[:INDEX] || raise)
        raise JSONP3::Pointer::SyntaxError, "index offset can't be zero" if @index.zero?

        @index = -@index if match[:SIGN] == "-"
      end

      @pointer = match[:POINTER] == "#" ? "#" : Pointer.new(match[:POINTER] || raise)
    end

    def to_s
      sign = @index.positive? ? "+" : ""
      index = @index.zero? ? "" : "#{sign}#{@index}"
      "#{@origin}#{index}#{@pointer}"
    end

    # Return a new JSON Pointer by applying this relative pointer to _pointer_.
    # @param pointer [String | Pointer]
    # @return [Pointer]
    def to(pointer)
      p = pointer.is_a?(String) ? Pointer.new(pointer) : pointer

      if @origin > p.tokens.length
        raise JSONP3::Pointer::IndexError,
              "origin (#{@origin}) exceeds root (#{p.tokens.length})"
      end

      tokens = @origin < 1 ? p.tokens[0..] || raise : p.tokens[0...-@origin] || raise
      tokens[-1] = (tokens[-1] || raise) + @index if @index != 0 && tokens.length.positive? && tokens[-1].is_a?(Integer)

      if @pointer == "#"
        tokens[-1] = "##{tokens[-1]}"
      else
        tokens.concat(@pointer.tokens) # steep:ignore
      end

      Pointer.new(Pointer.encode(tokens))
    end

    private

    # @param token [String]
    # @return [Integer]
    def parse_int(token)
      raise JSONP3::Pointer::SyntaxError, "unexpected leading zero" if token.start_with?("0") && token.length > 1
      raise JSONP3::Pointer::SyntaxError, "expected an integer, found '#{token}'" unless RE_INT.match?(token)

      token.to_i
    end
  end
end
