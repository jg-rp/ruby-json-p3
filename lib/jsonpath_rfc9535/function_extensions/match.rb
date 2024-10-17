# frozen_string_literal: true

# require "iregexp"

require_relative "../function"

module JSONPathRFC9535
  # The standard `count` function.
  class Match < FunctionExtension
    ARG_TYPES = [ExpressionType::VALUE, ExpressionType::VALUE].freeze
    RETURN_TYPE = ExpressionType::LOGICAL

    def call(string, pattern)
      return false unless pattern.is_a? String

      # ire = IREGEXP.from_iregexp(pattern)
      # TODO
      raise "not implemented"
    rescue IREGEXP.ParserError
      false
    end
  end
end
