# frozen_string_literal: true

require_relative "../function"

module JSONPathRFC9535
  # The standard `count` function.
  class Search < FunctionExtension
    ARG_TYPES = [ExpressionType::VALUE, ExpressionType::VALUE].freeze
    RETURN_TYPE = ExpressionType::LOGICAL

    def call(string, pattern)
      raise "not implemented"
    end
  end
end
