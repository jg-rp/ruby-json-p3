# frozen_string_literal: true

require_relative "errors"

module JSONP3
  # JSONPath
  module Path
    RE_FLOAT = /(?:-?\d+\.\d+(?:[eE][+-]?\d+)?)|(-?\d+[eE]-\d+)/
    RE_INDEX = /-?\d+/
    RE_INT = /-?\d+[eE]\+?\d+/

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity

    def self.tokenize(query)
      tokens = [] #: Array[t_token]
      length = query.size
      start = 0
      pos = 0

      while pos < length
        byte = query.getbyte(pos)

        case byte
        when nil
          break
        when 42 # *
          pos += 1
          tokens << [:token_asterisk, start, pos]
        when 64 # @
          pos += 1
          tokens << [:token_at, start, pos]
        when 58 # :
          pos += 1
          tokens << [:token_colon, start, pos]
        when 44 # ,
          pos += 1
          tokens << [:token_comma, start, pos]
        when 36 # $
          pos += 1
          tokens << [:token_dollar, start, pos]
        when 40 # (
          pos += 1
          tokens << [:token_lparen, start, pos]
        when 91 # [
          pos += 1
          tokens << [:token_lbracket, start, pos]
        when 41 # )
          pos += 1
          tokens << [:token_rparen, start, pos]
        when 93 # ]
          pos += 1
          tokens << [:token_rbracket, start, pos]
        when 63 # ?
          pos += 1
          tokens << [:token_question, start, pos]
        when 38 # &
          tokens << if query.getbyte(pos + 1) == 38
                      pos += 2
                      [:token_and, start, pos]
                    else
                      pos += 1
                      [:token_error, start, pos]
                    end
        when 124 # |
          tokens << if query.getbyte(pos + 1) == 124
                      pos += 2
                      [:token_or, start, pos]
                    else
                      pos += 1
                      [:token_error, start, pos]
                    end
        when 46 # .
          tokens << if query.getbyte(pos + 1) == 46
                      pos += 2
                      [:token_double_dot, start, pos]
                    else
                      pos += 1
                      [:token_dot, start, pos]
                    end
        when 61 # =
          tokens << if query.getbyte(pos + 1) == 61
                      pos += 2
                      [:token_eq, start, pos]
                    else
                      pos += 1
                      [:token_error, start, pos]
                    end
        when 33 # !
          tokens << if query.getbyte(pos + 1) == 61
                      pos += 2
                      [:token_ne, start, pos]
                    else
                      pos += 1
                      [:token_not, start, pos]
                    end
        when 62 # >
          tokens << if query.getbyte(pos + 1) == 61
                      pos += 2
                      [:token_ge, start, pos]
                    else
                      pos += 1
                      [:token_gt, start, pos]
                    end
        when 60 # <
          tokens << if query.getbyte(pos + 1) == 61
                      pos += 2
                      [:token_le, start, pos]
                    else
                      pos += 1
                      [:token_lt, start, pos]
                    end
        when 39, 34 # ' or "
          pos += 1
          token, pos = scan_string_literal(query, byte, pos)
          tokens << token
        else
          if name_first?(byte)
            pos += 1 while name_ch?(query.getbyte(pos) || 0)
            tokens << [:token_name, start, pos]
          elsif trivia?(byte)
            pos += 1 while trivia?(query.getbyte(pos) || 0)
            tokens << [:token_trivia, start, pos]
          elsif number_ch?(byte)
            if (match = query.match(RE_FLOAT, pos))
              pos = match.end(0) || raise
              tokens << [:token_float, start, pos]
            elsif (match = query.match(RE_INT, pos))
              pos = match.end(0) || raise
              tokens << [:token_int, start, pos]
            elsif (match = query.match(RE_INDEX, pos))
              pos = match.end(0) || raise
              tokens << [:token_index, start, pos]
            else
              pos += 1
              tokens << [:token_error, start, pos]
            end
          else
            pos += 1
            tokens << [:token_error, start, pos]
          end
        end

        start = pos
      end

      tokens
    end

    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    def self.scan_string_literal(query, byte, pos)
      start = pos
      length = query.size

      # @type var token: t_token
      # @type var kind: t_token_kind
      # @type var esc_kind: t_token_kind

      kind = byte == 39 ? :token_single_quoted_string : :token_double_quoted_string
      esc_kind = byte == 39 ? :token_single_quoted_esc_string : :token_double_quoted_esc_string

      while pos < length
        ch = query.getbyte(pos)
        case ch
        when 92 # \
          kind = esc_kind
          pos += 2
        when nil
          break
        when 39 # '
          token = [kind, start, pos]
          return [token, pos + 1] if esc_kind == :token_single_quoted_esc_string

          pos += 1
        when 34 # "
          token = [kind, start, pos]
          return [token, pos + 1] if esc_kind == :token_double_quoted_esc_string

          pos += 1
        else
          # Escaped strings get scanned by the parser, where invalid characters will be caught.
          kind = esc_kind if ch <= 0x1f
          pos += 1
        end
      end

      token = [:token_error, start, pos]
      raise JSONPathSyntaxError.new("unclosed string literal", token)
    end

    def self.name_first?(ch)
      (ch >= 48 && ch <= 57) || (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) || ch == 95 || (ch >= 0x80 && ch <= 0xffff)
    end

    def self.name_ch?(ch)
      (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) || ch == 95 || (ch >= 0x80 && ch <= 0xffff)
    end

    def self.number_ch?(ch)
      ch == 45 || (ch >= 48 && ch <= 57)
    end

    def self.trivia?(ch)
      ch == 32 || ch == 9 || ch == 10 || ch == 13 # rubocop: disable Style/MultipleComparison
    end

    # TODO: Move to Token module
    def self.get_token_value(token, query)
      query[token[1]...token.last] || raise
    end
  end
end
