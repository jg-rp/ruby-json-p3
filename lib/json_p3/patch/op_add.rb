# frozen_string_literal: true

module JSONP3
  class Patch
    # The JSON Patch _add_ operation.
    class OpAdd < Op
      # @param pointer [JSONPointer]
      # @param value [JSON-like value]
      def initialize(pointer, value)
        super()
        @pointer = pointer
        @value = value
      end

      def name
        "add"
      end

      def apply!(value, index)
        parent, obj = @pointer.resolve_with_parent(value)
        return @value if parent == JSONP3::Pointer::UNDEFINED && @pointer.tokens.empty?

        if parent == JSONP3::Pointer::UNDEFINED
          raise JSONP3::Patch::Error,
                "no such property or item '#{@pointer.parent}' (#{name}:#{index})"
        end

        target = @pointer.tokens.last
        if parent.is_a?(Array)
          if obj == JSONP3::Pointer::UNDEFINED
            raise JSONP3::Patch::Error, "index out of range (#{name}:#{index})" unless target == "-"

            parent << @value
          else
            parent.insert(target.to_i, @value)
          end
        elsif parent.is_a?(Hash)
          parent[target] = @value
        else
          raise JSONP3::Patch::Error, "unexpected operation on #{parent.class} (#{name}:#{index})"
        end

        value
      end

      def to_h
        { "op" => name, "path" => @pointer.to_s, "value" => @value }
      end
    end
  end
end
