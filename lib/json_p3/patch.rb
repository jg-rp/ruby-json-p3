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
      raise "JSON Patch operations must implement #to_hash"
    end
  end

  # The JSON Patch _add_ operation.
  class OpAdd < Op
    # @param pointer [JSONPointer]
    # @param value [JSON-like value]
    def initialize(pointer, value)
      super
      @pointer = pointer
      @value = value
    end

    def name
      "add"
    end

    def apply(value, index)
      parent, obj = @pointer.resolve_with_parent(value)
      return @value if parent == JSONP3::JSONPointer::UNDEFINED

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
      { "op" => name, "path" => @pointer.to_s }
    end
  end

  # The JSON Patch _remove_ operation.
  class OpRemove < Op
    # @param pointer [JSONPointer]
    def initialize(pointer)
      super
      @pointer = pointer
    end

    def name
      "remove"
    end

    def apply(value, index)
      parent, obj = @pointer.resolve_with_parent(value)
      raise JSONPatchError, "can't remove root (#{name}:#{index})" if parent == JSONP3::JSONPointer::UNDEFINED

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
      super
      @pointer = pointer
      @value = value
    end

    def name
      "replace"
    end

    def apply(value, index)
      parent, obj = @pointer.resolve_with_parent(value)
      return @value if parent == JSONP3::JSONPointer::UNDEFINED

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
      super
      @from = from
      @pointer = pointer
    end

    def name
      "move"
    end
  end

  # The JSON Patch _copy_ operation.
  class OpCopy < Op
    # @param from [JSONPointer]
    # @param pointer [JSONPointer]
    def initialize(from, pointer)
      super
      @from = from
      @pointer = pointer
    end

    def name
      "copy"
    end
  end

  # The JSON Patch _test_ operation.
  class OpTest < Op
    # @param pointer [JSONPointer]
    # @param value [JSON-like value]
    def initialize(pointer, value)
      super
      @pointer = pointer
      @value = value
    end

    def name
      "test"
    end
  end

  # A JSON Patch containing zero or more patch operations.
  class JSONPatch
    # @param ops [Array<Op>?]
    def initialize(ops)
      @ops = ops
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

    def ensure_pointer(pointer, op, index)
      return pointer unless pointer.is_a?(String)

      JSONP3::JSONPointer.new(pointer)
    rescue JSONPointerError
      raise JSONPatchError, "#{$ERROR_INFO} (#{op}:#{index})"
    end
  end
end
