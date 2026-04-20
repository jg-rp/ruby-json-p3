# frozen_string_literal: true

module JSONP3
  class Patch
    # The JSON Patch _move_ operation.
    class OpMove < Op
      # @param from [JSONPointer]
      # @param pointer [JSONPointer]
      def initialize(from, pointer)
        super()
        @from = from
        @pointer = pointer
      end

      def name
        "move"
      end

      def apply!(value, index)
        if @pointer.relative_to?(@from)
          raise JSONP3::Patch::Error,
                "can't move object to one of its children (#{name}:#{index})"
        end

        # Grab the source value.
        source_parent, source_obj = @from.resolve_with_parent(value)
        if source_obj == JSONP3::Pointer::UNDEFINED
          raise JSONP3::Patch::Error,
                "source object does not exist (#{name}:#{index})"
        end

        source_target = @from.tokens.last
        if source_target == JSONP3::Pointer::UNDEFINED
          raise JSONP3::Patch::Error,
                "unexpected operation (#{name}:#{index})"
        end

        # Delete the target value from the source location.
        if source_parent.is_a?(Array)
          source_parent.delete_at(source_target.to_i)
        elsif source_parent.is_a?(Hash)
          source_parent.delete(source_target)
        end

        # Find the parent of the destination pointer.
        dest_parent, _dest_obj = @pointer.resolve_with_parent(value)
        return source_obj if dest_parent == JSONP3::Pointer::UNDEFINED

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
            dest_parent[dest_target.to_i] = source_obj
          end
        elsif dest_parent.is_a?(Hash)
          dest_parent[dest_target] = source_obj
        end

        value
      end

      def to_h
        { "op" => name, "from" => @from.to_s, "path" => @pointer.to_s }
      end
    end
  end
end
