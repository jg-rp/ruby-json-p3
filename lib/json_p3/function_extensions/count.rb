# frozen_string_literal: true

require_relative "../function"

module JSONP3
  # The standard `count` function.
  class Count < FunctionExtension
    ARG_TYPES = [:nodes_expression].freeze
    RETURN_TYPE = :value_expression

    def call(node_list)
      node_list.length
    end
  end
end
