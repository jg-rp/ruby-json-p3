# frozen_string_literal: true

module JSONP3
  class ExpressionType
    VALUE = :value_expression
    LOGICAL = :logical_expression
    NODES = :nodes_expression
  end

  # Base class for all filter functions.
  class FunctionExtension
    def call(*_args, **_kwargs)
      raise "function extensions must implement `call()`"
    end
  end
end
