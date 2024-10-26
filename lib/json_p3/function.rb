# frozen_string_literal: true

module JSONP3
  # Base class for all filter functions.
  class FunctionExtension
    def call(*_args, **_kwargs)
      raise "function extensions must implement `call()`"
    end
  end
end
