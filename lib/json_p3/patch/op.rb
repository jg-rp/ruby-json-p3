# frozen_string_literal: true

module JSONP3
  class Patch
    # Base class for all JSON Patch operations
    class Op
      # Return the name of the patch operation.
      def name
        raise "JSON Patch operations must implement #name"
      end

      # Apply the patch operation to _value_.
      def apply!(_value, _index)
        raise "JSON Patch operations must implement apply!(value, index)"
      end

      # Return a JSON-like representation of this patch operation.
      def to_h
        raise "JSON Patch operations must implement #to_h"
      end
    end
  end
end
