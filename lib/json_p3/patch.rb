# frozen_string_literal: true

require "English"
require_relative "errors"

module JSONP3
  # Base class for all JSON Patch operations
  class Op
    # Return the name of the patch operation.
    def name
      raise "JSON Patch operations must implement #name"
    end

    # Apply the patch operation to _value_.
    def apply(_value, _index)
      raise "JSON Patch operations must implement apply(value, index)"
    end

    # Return a JSON-like representation of this patch operation.
    def to_h
      raise "JSON Patch operations must implement #to_h"
    end
  end

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

    def apply(value, index)
      parent, obj = @pointer.resolve_with_parent(value)
      return @value if parent == JSONP3::JSONPointer::UNDEFINED && @pointer.tokens.empty?

      if parent == JSONP3::JSONPointer::UNDEFINED
        raise JSONPatchError,
              "no such property or item '#{@pointer.parent}' (#{name}:#{index})"
      end

      target = @pointer.tokens.last
      if parent.is_a?(Array)
        if obj == JSONP3::JSONPointer::UNDEFINED
          raise JSONPatchError, "index out of range (#{name}:#{index})" unless target == "-"

          parent << @value
        else
          parent.insert(target.to_i, @value)
        end
      elsif parent.is_a?(Hash)
        parent[target] = @value
      else
        raise JSONPatchError, "unexpected operation on #{parent.class} (#{name}:#{index})"
      end

      value
    end

    def to_h
      { "op" => name, "path" => @pointer.to_s, "value" => @value }
    end
  end

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

    def apply(value, index)
      parent, obj = @pointer.resolve_with_parent(value)

      if parent == JSONP3::JSONPointer::UNDEFINED && @pointer.tokens.empty?
        raise JSONPatchError,
              "can't remove root (#{name}:#{index})"
      end

      if parent == JSONP3::JSONPointer::UNDEFINED
        raise JSONPatchError,
              "no such property or item '#{@pointer.parent}' (#{name}:#{index})"
      end

      target = @pointer.tokens.last
      if target == JSONP3::JSONPointer::UNDEFINED
        raise JSONPatchError,
              "unexpected operation (#{name}:#{index})"
      end

      if parent.is_a?(Array)
        raise JSONPatchError, "no item to remove (#{name}:#{index})" if obj == JSONP3::JSONPointer::UNDEFINED

        parent.delete_at(target.to_i)
      elsif parent.is_a?(Hash)
        raise JSONPatchError, "no property to remove (#{name}:#{index})" if obj == JSONP3::JSONPointer::UNDEFINED

        parent.delete(target)
      else
        raise JSONPatchError, "unexpected operation on #{parent.class} (#{name}:#{index})"
      end

      value
    end

    def to_h
      { "op" => name, "path" => @pointer.to_s }
    end
  end

  # The JSON Patch _replace_ operation.
  class OpReplace < Op
    # @param pointer [JSONPointer]
    # @param value [JSON-like value]
    def initialize(pointer, value)
      super()
      @pointer = pointer
      @value = value
    end

    def name
      "replace"
    end

    def apply(value, index)
      parent, obj = @pointer.resolve_with_parent(value)
      return @value if parent == JSONP3::JSONPointer::UNDEFINED && @pointer.tokens.empty?

      if parent == JSONP3::JSONPointer::UNDEFINED
        raise JSONPatchError,
              "no such property or item '#{@pointer.parent}' (#{name}:#{index})"
      end

      target = @pointer.tokens.last
      if target == JSONP3::JSONPointer::UNDEFINED
        raise JSONPatchError,
              "unexpected operation (#{name}:#{index})"
      end

      if parent.is_a?(Array)
        raise JSONPatchError, "no item to replace (#{name}:#{index})" if obj == JSONP3::JSONPointer::UNDEFINED

        parent[target.to_i] = @value
      elsif parent.is_a?(Hash)
        raise JSONPatchError, "no property to replace (#{name}:#{index})" if obj == JSONP3::JSONPointer::UNDEFINED

        parent[target] = @value
      else
        raise JSONPatchError, "unexpected operation on #{parent.class} (#{name}:#{index})"
      end

      value
    end

    def to_h
      { "op" => name, "path" => @pointer.to_s, "value" => @value }
    end
  end

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

    def apply(value, index)
      if @pointer.relative_to?(@from)
        raise JSONPatchError,
              "can't move object to one of its children (#{name}:#{index})"
      end

      # Grab the source value.
      source_parent, source_obj = @from.resolve_with_parent(value)
      if source_obj == JSONP3::JSONPointer::UNDEFINED
        raise JSONPatchError,
              "source object does not exist (#{name}:#{index})"
      end

      source_target = @from.tokens.last
      if source_target == JSONP3::JSONPointer::UNDEFINED
        raise JSONPatchError,
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
      return source_obj if dest_parent == JSONP3::JSONPointer::UNDEFINED

      dest_target = @pointer.tokens.last
      if dest_target == JSONP3::JSONPointer::UNDEFINED
        raise JSONPatchError,
              "unexpected operation (#{name}:#{index})"
      end

      # Write the source value to the destination.
      if dest_parent.is_a?(Array)
        dest_parent[dest_target.to_i] = source_obj
      elsif dest_parent.is_a?(Hash)
        dest_parent[dest_target] = source_obj
      end

      value
    end

    def to_h
      { "op" => name, "from" => @from.to_s, "path" => @pointer.to_s }
    end
  end

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

    def apply(value, index)
      # Grab the source value.
      _source_parent, source_obj = @from.resolve_with_parent(value)
      if source_obj == JSONP3::JSONPointer::UNDEFINED
        raise JSONPatchError,
              "source object does not exist (#{name}:#{index})"
      end

      # Find the parent of the destination pointer.
      dest_parent, _dest_obj = @pointer.resolve_with_parent(value)
      return deep_copy(source_obj) if dest_parent == JSONP3::JSONPointer::UNDEFINED

      dest_target = @pointer.tokens.last
      if dest_target == JSONP3::JSONPointer::UNDEFINED
        raise JSONPatchError,
              "unexpected operation (#{name}:#{index})"
      end

      # Write the source value to the destination.
      if dest_parent.is_a?(Array)
        dest_parent.insert(dest_target.to_i, deep_copy(source_obj))
      elsif dest_parent.is_a?(Hash)
        dest_parent[dest_target] = deep_copy(source_obj)
      else
        raise JSONPatchError, "unexpected operation on #{dest_parent.class} (#{name}:#{index})"
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

    def apply(value, index)
      obj = @pointer.resolve(value)
      raise JSONPatchTestFailure, "test failed (#{name}:#{index})" if obj != @value

      value
    end

    def to_h
      { "op" => name, "path" => @pointer.to_s, "value" => @value }
    end
  end

  # A JSON Patch containing zero or more patch operations.
  class JSONPatch
    # @param ops [Array<Op | Hash<String, untyped>>?]
    def initialize(ops = nil)
      @ops = []
      build(ops) unless ops.nil?
    end

    # @param pointer [String | JSONPointer]
    # @param value [JSON-like value]
    # @return [self]
    def add(pointer, value)
      @ops.push(OpAdd.new(ensure_pointer(pointer, :add, @ops.length), value))
      self
    end

    # @param pointer [String | JSONPointer]
    # @return [self]
    def remove(pointer)
      @ops.push(OpRemove.new(ensure_pointer(pointer, :remove, @ops.length)))
      self
    end

    # @param pointer [String | JSONPointer]
    # @param value [JSON-like value]
    # @return [self]
    def replace(pointer, value)
      @ops.push(OpReplace.new(ensure_pointer(pointer, :replace, @ops.length), value))
      self
    end

    # @param from [String | JSONPointer]
    # @param pointer [String | JSONPointer]
    # @return [self]
    def move(from, pointer)
      @ops.push(OpMove.new(
                  ensure_pointer(from, :move, @ops.length),
                  ensure_pointer(pointer, :move, @ops.length)
                ))
      self
    end

    # @param from [String | JSONPointer]
    # @param pointer [String | JSONPointer]
    # @return [self]
    def copy(from, pointer)
      @ops.push(OpCopy.new(
                  ensure_pointer(from, :copy, @ops.length),
                  ensure_pointer(pointer, :copy, @ops.length)
                ))
      self
    end

    # @param pointer [String | JSONPointer]
    # @param value [JSON-like value]
    # @return [self]
    def test(pointer, value)
      @ops.push(OpTest.new(ensure_pointer(pointer, :test, @ops.length), value))
      self
    end

    # Apply this patch to JSON-like value _value_.
    def apply(value)
      @ops.each_with_index { |op, i| value = op.apply(value, i) }
      value
    end

    def to_a
      @ops.map(&:to_h)
    end

    private

    # @param ops [Array<Op | Hash<String, untyped>>?]
    # @return void
    def build(ops)
      ops.each_with_index do |obj, i|
        if obj.is_a?(Op)
          @ops << obj
          next
        end

        case obj["op"]
        when "add"
          add(op_pointer(obj, "path", "add", i), op_value(obj, "value", "add", i))
        when "remove"
          remove(op_pointer(obj, "path", "remove", i))
        when "replace"
          replace(op_pointer(obj, "path", "replace", i), op_value(obj, "value", "replace", i))
        when "move"
          move(op_pointer(obj, "from", "move", i), op_pointer(obj, "path", "move", i))
        when "copy"
          copy(op_pointer(obj, "from", "copy", i), op_pointer(obj, "path", "copy", i))
        when "test"
          test(op_pointer(obj, "path", "test", i), op_value(obj, "value", "test", i))
        else
          raise JSONPatchError,
                "expected 'op' to be one of 'add', 'remove', 'replace', 'move', 'copy' or 'test' (#{obj["op"]}:#{i})"
        end
      end
    end

    def op_pointer(obj, key, op, index)
      raise JSONPatchError, "missing property '#{key}' (#{op}:#{index})" unless obj.key?(key)

      JSONP3::JSONPointer.new(obj[key])
    rescue JSONPointerError
      raise JSONPatchError, "#{$ERROR_INFO} (#{op}:#{index})"
    end

    def op_value(obj, key, op, index)
      raise JSONPatchError, "missing property '#{key}' (#{op}:#{index})" unless obj.key?(key)

      obj[key]
    end

    def ensure_pointer(pointer, op, index)
      return pointer unless pointer.is_a?(String)

      JSONP3::JSONPointer.new(pointer)
    rescue JSONPointerError
      raise JSONPatchError, "#{$ERROR_INFO} (#{op}:#{index})"
    end
  end
end
