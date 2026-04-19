# frozen_string_literal: true

module JSONP3
  module Path
    # The standard `count` function.
    class Count < FunctionExtension
      ARG_TYPES = [:nodes_expression].freeze
      RETURN_TYPE = :value_expression

      def call(node_list)
        node_list.length
      end
    end
  end
end
