# frozen_string_literal: true

module JSONPathRFC9535 # rubocop:disable Style/Documentation
  # Replace escape sequences with their equivalent Unicode code point.
  # @param value [String]
  # @param quote [String] one of '"' or "'".
  # @param token [Token]
  # @return [String] A new string without escape seqeuences.
  def self.unescape_string(value, quote, token) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    unescaped = String.new(encoding: "UTF-8")
    index = 0
    length = value.length

    while index < length
      ch = value[index] || raise
      if ch == "\\"
        index += 1
        case value[index]
        when quote
          unescaped << quote
        when "\\"
          unescaped << "\\"
        when "/"
          unescaped << "/"
        when "b"
          unescaped << "\x08"
        when "f"
          unescaped << "\x0C"
        when "n"
          unescaped << "\n"
        when "r"
          unescaped << "\r"
        when "t"
          unescaped << "\t"
        when "u"
          code_point, index = JSONPathRFC9535.decode_hex_char(value, index, token)
          unescaped << JSONPathRFC9535.code_point_to_string(code_point, token)
        else
          raise JSONPathSyntaxError.new("unknown escape sequence", token)
        end
      else
        raise JSONPathSyntaxError.new("invalid character", token) if ch.ord <= 0x1F

        unescaped << ch
      end

      index += 1

    end

    unescaped
  end

  def self.decode_hex_char(value, index, token) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
    length = value.length

    raise JSONPathSyntaxError.new("incomplete escape seqeuence", token) if index + 4 >= length

    index += 1 # move past 'u'
    code_point = parse_hex_digits(value[index...index + 4], token)

    raise JSONPathSyntaxError.new("unexpected low surrogate", token) if low_surrogate?(code_point)

    return [code_point, index + 3] unless high_surrogate?(code_point)

    unless index + 9 < length && value[index + 4] == "\\" && value[index + 5] == "u"
      raise JSONPathSyntaxError.new("incomplete escape seqeuence", token)
    end

    low_surrogate = parse_hex_digits(value[index + 6...index + 10], token)

    raise JSONPathSyntaxError.new("unexpected low surrogate", token) unless low_surrogate?(low_surrogate)

    code_point = 0x10000 + (
      ((code_point & 0x03FF) << 10) | (low_surrogate & 0x03FF)
    )

    [code_point, index + 9]
  end

  def self.parse_hex_digits(digits, token) # rubocop:disable Metrics/MethodLength
    code_point = 0
    digits.each_byte do |b|
      code_point <<= 4
      case b
      when 48..57
        code_point |= b - 48
      when 65..70
        code_point |= b - 65 + 10
      when 97..102
        code_point |= b - 97 + 10
      else
        raise JSONPathSyntaxError.new("invalid escape seqeuence", token)
      end
    end
    code_point
  end

  def self.high_surrogate?(code_point)
    code_point >= 0xD800 && code_point <= 0xDBFF
  end

  def self.low_surrogate?(code_point)
    code_point >= 0xDC00 && code_point <= 0xDFFF
  end

  def self.code_point_to_string(code_point, token)
    raise JSONPathSyntaxError.new("invalid character", token) if code_point <= 0x1F

    code_point.chr(Encoding::UTF_8)
  end
end
