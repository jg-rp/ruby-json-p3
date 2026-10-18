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

      private

      # Add _obj_ to _parent_ at _target_ following the semantics of the JSON
      # Patch _add_ operation: insert into arrays, set object members.
      def add_member(parent, target, obj, index)
        if parent.is_a?(Array)
          if target == "-"
            parent << obj
          elsif target.is_a?(Integer) && target <= parent.length
            parent.insert(target, obj)
          else
            raise JSONP3::Patch::Error, "index out of range (#{name}:#{index})"
          end
        elsif parent.is_a?(Hash)
          parent[member_key(parent, target)] = obj
        else
          raise JSONP3::Patch::Error, "unexpected operation on #{parent.class} (#{name}:#{index})"
        end
      end

      # Return the key of _parent_ identified by pointer token _target_.
      # Pointer tokens that look like array indices are integers, but object
      # member names are strings.
      def member_key(parent, target)
        parent.key?(target) ? target : target.to_s
      end
    end
  end
end
