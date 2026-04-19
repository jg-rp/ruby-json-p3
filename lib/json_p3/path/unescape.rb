# frozen_string_literal: true

require "strscan"

module JSONP3
  # JSONPath query expressions.
  module Path
    RE_SLASH_U = /\\u([0-9a-fA-F]{4})/

    # Replace escape sequences with their equivalent Unicode code point.
    def self.unescape(value, token, query)
      unescaped = String.new(encoding: "UTF-8")
      scanner = StringScanner.new(value)

      until scanner.eos?
        if scanner.scan(RE_SLASH_U)
          code_point = (scanner.captures&.first || raise).to_i(16)

          if low_surrogate?(code_point)
            raise JSONP3::Path::SyntaxError.new(
              "unexpected low surrogate",
              token,
              query
            )
          end

          if high_surrogate?(code_point)
            unless scanner.scan(RE_SLASH_U)
              raise JSONP3::Path::SyntaxError.new(
                "expected a low surrogate",
                token,
                query
              )
            end

            low_surrogate = (scanner.captures&.first || raise).to_i(16)

            unless low_surrogate?(low_surrogate)
              raise JSONP3::Path::SyntaxError.new(
                "expected a low surrogate",
                token,
                query
              )
            end

            code_point = 0x10000 + (
              ((code_point & 0x03FF) << 10) | (low_surrogate & 0x03FF)
            )
          end

          if code_point <= 0x1f
            raise JSONP3::Path::SyntaxError.new(
              "invalid character #{code_point}",
              token,
              query
            )
          end

          unescaped << code_point.chr(Encoding::UTF_8)
          next
        end

        ch = scanner.getch

        break if ch.nil?

        unless ch == "\\"
          if ch.ord <= 0x1f
            raise JSONP3::Path::SyntaxError.new(
              "invalid character #{ch.ord}",
              token,
              query
            )
          end
          unescaped << ch
          next
        end

        ch = scanner.getch

        case ch
        when "\""
          if token.first == :token_single_quoted_esc_string
            raise JSONP3::Path::SyntaxError.new(
              "unexpected \\\" escape in single quoted string",
              token,
              query
            )
          end
          unescaped << "\""
        when "'"
          if token.first == :token_double_quoted_esc_string
            raise JSONP3::Path::SyntaxError.new(
              "unexpected \\' escape in double quoted string",
              token,
              query
            )
          end
          unescaped << "'"
        when "\\"
          unescaped << "\\"
        when "/"
          unescaped << "/"
        when "b"
          unescaped << "\x08"
        when "f"
          unescaped << "\x0c"
        when "n"
          unescaped << "\n"
        when "r"
          unescaped << "\r"
        when "t"
          unescaped << "\t"
        when "u"
          raise JSONP3::Path::SyntaxError.new("unexpected \\u escape sequence", token, query)
        when nil
          raise JSONP3::Path::SyntaxError.new("incomplete escape sequence", token, query)
        else
          raise JSONP3::Path::SyntaxError.new("unknown escape sequence", token, query)
        end
      end

      unescaped
    end

    def self.high_surrogate?(code_point)
      code_point.between?(0xD800, 0xDBFF)
    end

    def self.low_surrogate?(code_point)
      code_point.between?(0xDC00, 0xDFFF)
    end
  end
end
