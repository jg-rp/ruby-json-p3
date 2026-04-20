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
        return deep_copy(source_obj) if dest_parent == JSONP3::Pointer::UNDEFINED

        dest_target = @pointer.tokens.last
        if dest_target == JSONP3::Pointer::UNDEFINED
          raise JSONP3::Patch::Error,
                "unexpected operation (#{name}:#{index})"
        end

        # Write the source value to the destination.
        if dest_parent.is_a?(Array)
          if dest_target == "-"
            dest_parent << source_obj
          else
            dest_parent.insert(dest_target.to_i, deep_copy(source_obj))
          end
        elsif dest_parent.is_a?(Hash)
          dest_parent[dest_target] = deep_copy(source_obj)
        else
          raise JSONP3::Patch::Error, "unexpected operation on #{dest_parent.class} (#{name}:#{index})"
        end

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
