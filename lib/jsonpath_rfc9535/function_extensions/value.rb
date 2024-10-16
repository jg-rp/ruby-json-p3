# frozen_string_literal: true

require_relative "../function"

module JsonpathRfc9535
  # The standard `count` function.
  class Value < FunctionExtension
    ARG_TYPES = [ExpressionType::NODES].freeze
    RETURN_TYPE = ExpressionType::VALUE

    def call(node_list)
      nodes.length == 1 ? node_list.first.value : :nothing
    end
  end
end
