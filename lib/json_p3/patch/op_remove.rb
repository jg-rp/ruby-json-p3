# frozen_string_literal: true

module JSONP3
  class Patch
    # The JSON Patch _remove_ operation.
    class OpRemove < Op
      # @param pointer [JSONPointer]
      def initialize(pointer)
        super()
        @pointer = pointer
      end

      def name
        "remove"
      end

      def apply!(value, index)
        parent, obj = @pointer.resolve_with_parent(value)

        if parent == JSONP3::Pointer::UNDEFINED && @pointer.tokens.empty?
          raise JSONP3::Patch::Error,
                "can't remove root (#{name}:#{index})"
        end

        if parent == JSONP3::Pointer::UNDEFINED
          raise JSONP3::Patch::Error,
                "no such property or item '#{@pointer.parent}' (#{name}:#{index})"
        end

        target = @pointer.tokens.last
        if target == JSONP3::Pointer::UNDEFINED
          raise JSONP3::Patch::Error,
                "unexpected operation (#{name}:#{index})"
        end

        if parent.is_a?(Array)
          raise JSONP3::Patch::Error, "no item to remove (#{name}:#{index})" if obj == JSONP3::Pointer::UNDEFINED

          parent.delete_at(target.to_i)
        elsif parent.is_a?(Hash)
          raise JSONP3::Patch::Error, "no property to remove (#{name}:#{index})" if obj == JSONP3::Pointer::UNDEFINED

          parent.delete(target)
        else
          raise JSONP3::Patch::Error, "unexpected operation on #{parent.class} (#{name}:#{index})"
        end

        value
      end

      def to_h
        { "op" => name, "path" => @pointer.to_s }
      end
    end
  end
end
