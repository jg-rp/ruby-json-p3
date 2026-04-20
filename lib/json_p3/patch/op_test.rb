# frozen_string_literal: true

module JSONP3
  class Patch
    # The JSON Patch _test_ operation.
    class OpTest < Op
      # @param pointer [JSONPointer]
      # @param value [JSON-like value]
      def initialize(pointer, value)
        super()
        @pointer = pointer
        @value = value
      end

      def name
        "test"
      end

      def apply!(value, index)
        obj = @pointer.resolve(value)
        raise JSONP3::Patch::TestFailure, "test failed (#{name}:#{index})" if obj != @value

        value
      end

      def to_h
        { "op" => name, "path" => @pointer.to_s, "value" => @value }
      end
    end
  end
end
