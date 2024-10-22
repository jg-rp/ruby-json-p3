# frozen_string_literal: true

require_relative "../function"

module JSONPathRFC9535
  # The standard `value` function.
  class Value < FunctionExtension
    ARG_TYPES = [ExpressionType::NODES].freeze
    RETURN_TYPE = ExpressionType::VALUE

    def call(node_list)
      node_list.length == 1 ? node_list.first.value : :nothing
    end
  end
end
