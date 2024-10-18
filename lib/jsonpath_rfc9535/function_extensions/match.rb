# frozen_string_literal: true

require_relative "../function"
require_relative "pattern"

module JSONPathRFC9535
  # The standard `count` function.
  class Match < FunctionExtension
    ARG_TYPES = [ExpressionType::VALUE, ExpressionType::VALUE].freeze
    RETURN_TYPE = ExpressionType::LOGICAL

    # @param value [String]
    # @param pattern [String]
    # @return Boolean
    def call(value, pattern)
      return false unless pattern.is_a? String

      # TODO: cache pattern as regex
      # TODO: check for I-Regexp compliance
      re = Regexp.new(full_match(pattern))
      re.match?(value)
    rescue RegexpError, TypeError
      # TODO: option to raise for debugging
      false
    end

    private

    def full_match(pattern)
      parts = []
      explicit_caret = pattern.start_with?("^")
      explicit_dollar = pattern.end_with?("$")

      # Replace '^' with '\A' and '$' with '\z'
      pattern = pattern.sub("^", "\\A") if explicit_caret
      pattern = "#{pattern[..-1]}\\z" if explicit_dollar

      # Wrap with '\A' and '\z' if they are not already part of the pattern.
      parts << "\\A(?:" if !explicit_caret && !explicit_dollar
      parts << JSONPathRFC9535.map_iregexp(pattern)
      parts << ")\\z" if !explicit_caret && !explicit_dollar
      parts.join("")
    end
  end
end
