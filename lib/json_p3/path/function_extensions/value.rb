# frozen_string_literal: true

module JSONP3
  module Path
    # The standard `value` function.
    class Value < FunctionExtension
      ARG_TYPES = [:nodes_expression].freeze
      RETURN_TYPE = :value_expression

      def call(node_list)
        node_list.length == 1 ? node_list.first.value : :nothing
      end
    end
  end
end
