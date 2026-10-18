# frozen_string_literal: true

module JSONP3
  class Patch
    # The JSON Patch _copy_ operation.
    class OpCopy < Op
      # @param from [JSONPointer]
      # @param pointer [JSONPointer]
      def initialize(from, pointer)
        super()
        @from = from
        @pointer = pointer
      end

      def name
        "copy"
      end

      def apply!(value, index)
        # Grab the source value.
        _source_parent, source_obj = @from.resolve_with_parent(value)
        if source_obj == JSONP3::Pointer::UNDEFINED
          raise JSONP3::Patch::Error,
                "source object does not exist (#{name}:#{index})"
        end

        # Find the parent of the destination pointer.
        dest_parent, _dest_obj = @pointer.resolve_with_parent(value)
        return deep_copy(source_obj) if @pointer.tokens.empty?

        if dest_parent == JSONP3::Pointer::UNDEFINED
          raise JSONP3::Patch::Error,
                "no such property or item '#{@pointer.parent}' (#{name}:#{index})"
        end

        # Write the source value to the destination.
        add_member(dest_parent, @pointer.tokens.last, deep_copy(source_obj), index)
        value
      end

      def to_h
        { "op" => name, "from" => @from.to_s, "path" => @pointer.to_s }
      end

      private

      def deep_copy(obj)
        Marshal.load(Marshal.dump(obj))
      end
    end
  end
end
