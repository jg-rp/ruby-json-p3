# frozen_string_literal: true

require_relative "../function"

module JSONPathRFC9535
  # The standard `count` function.
  class Length < FunctionExtension
    ARG_TYPES = [ExpressionType::VALUE].freeze
    RETURN_TYPE = ExpressionType::VALUE

    def call(obj)
      obj.length
    rescue StandardError
      :nothing
    end
  end
end
