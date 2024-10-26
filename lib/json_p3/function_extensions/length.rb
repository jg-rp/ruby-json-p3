# frozen_string_literal: true

require_relative "../function"

module JSONP3
  # The standard `length` function.
  class Length < FunctionExtension
    ARG_TYPES = [:value_expression].freeze
    RETURN_TYPE = :value_expression

    def call(obj)
      return :nothing unless obj.is_a?(Array) || obj.is_a?(Hash) || obj.is_a?(String)

      obj.length
    end
  end
end
