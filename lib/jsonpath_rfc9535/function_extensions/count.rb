# frozen_string_literal: true

require_relative "../function"

module JsonpathRfc9535
  # The standard `count` function.
  class Count < FunctionExtension
    ARG_TYPES = [ExpressionType::NODES].freeze
    RETURN_TYPE = ExpressionType::VALUE

    def call(node_list)
      node_list.length
    end
  end
end
