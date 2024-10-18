# frozen_string_literal: true

require_relative "../function"
require_relative "pattern"

module JSONPathRFC9535
  # The standard `count` function.
  class Search < FunctionExtension
    ARG_TYPES = [ExpressionType::VALUE, ExpressionType::VALUE].freeze
    RETURN_TYPE = ExpressionType::LOGICAL

    # @param value [String]
    # @param pattern [String]
    # @return Boolean
    def call(value, pattern)
      return false unless pattern.is_a? String

      # TODO: cache pattern as regex
      # TODO: check for I-Regexp compliance
      re = Regexp.new(pattern)
      re.match?(value)
    rescue RegexpError, TypeError
      # TODO: option to raise for debugging
      false
    end
  end
end
