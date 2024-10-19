# frozen_string_literal: true

module JSONPathRFC9535 # rubocop:disable Style/Documentation
  # Map I-Regexp pattern to Ruby regex pattern.
  # @param pattern [String]
  # @return [String]
  def self.map_iregexp(pattern) # rubocop:disable Metrics/MethodLength
    escaped = false
    char_class = false
    mapped = String.new(encoding: "UTF-8")

    pattern.each_char do |c|
      if escaped
        mapped << c
        escaped = false
        next
      end

      case c
      when "."
        # mapped << (char_class ? c : "(?:(?![\\r\\n])\\P{Cs}|\\p{Cs}\\p{Cs})")
        mapped << (char_class ? c : "[^\\n\\r]")
      when "\\"
        escaped = true
        mapped << "\\"
      when "["
        char_class = true
        mapped << "["
      when "]"
        char_class = false
        mapped << "]"
      else
        mapped << c
      end
    end

    mapped
  end
end
