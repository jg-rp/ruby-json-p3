# frozen_string_literal: true

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
    # @param path [JSONPointer]
    # @param value [JSON-like value]
    def initialize(path, value)
      super
      @path = path
      @value = value
    end

    def name
      "add"
    end
  end

  # The JSON Patch _remove_ operation.
  class OpRemove < Op
    # @param path [JSONPointer]
    def initialize(path)
      super
      @path = path
    end

    def name
      "remove"
    end
  end

  # The JSON Patch _replace_ operation.
  class OpReplace < Op
    # @param path [JSONPointer]
    # @param value [JSON-like value]
    def initialize(path, value)
      super
      @path = path
      @value = value
    end

    def name
      "replace"
    end
  end

  # The JSON Patch _move_ operation.
  class OpMove < Op
    # @param from [JSONPointer]
    # @param path [JSONPointer]
    def initialize(from, path)
      super
      @from = from
      @path = path
    end

    def name
      "move"
    end
  end

  # The JSON Patch _copy_ operation.
  class OpCopy < Op
    # @param from [JSONPointer]
    # @param path [JSONPointer]
    def initialize(from, path)
      super
      @from = from
      @path = path
    end

    def name
      "copy"
    end
  end

  # The JSON Patch _test_ operation.
  class OpTest < Op
    # @param path [JSONPointer]
    # @param value [JSON-like value]
    def initialize(path, value)
      super
      @path = path
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

    # @param path [String | JSONPointer]
    # @param value [JSON-like value]
    # @return [self]
    def add(path, value)
      @ops.push(OpAdd.new(ensure_pointer(path, :add, @ops.length), value))
      self
    end

    # @param path [String | JSONPointer]
    # @return [self]
    def remove(path)
      @ops.push(OpRemove.new(ensure_pointer(path, :remove, @ops.length)))
      self
    end

    # @param path [String | JSONPointer]
    # @param value [JSON-like value]
    # @return [self]
    def replace(path, value)
      @ops.push(OpReplace.new(ensure_pointer(path, :replace, @ops.length), value))
      self
    end

    # @param from [String | JSONPointer]
    # @param path [String | JSONPointer]
    # @return [self]
    def move(from, path)
      @ops.push(OpMove.new(
                  ensure_pointer(from, :move, @ops.length),
                  ensure_pointer(path, :move, @ops.length)
                ))
      self
    end

    # @param from [String | JSONPointer]
    # @param path [String | JSONPointer]
    # @return [self]
    def copy(from, path)
      @ops.push(OpCopy.new(
                  ensure_pointer(from, :copy, @ops.length),
                  ensure_pointer(path, :copy, @ops.length)
                ))
      self
    end

    # @param path [String | JSONPointer]
    # @param value [JSON-like value]
    # @return [self]
    def test(path, value)
      @ops.push(OpTest.new(ensure_pointer(path, :test, @ops.length), value))
      self
    end

    # Apply this patch to JSON-like value _value_.
    def apply(value)
      # TODO:
      raise "Not Implemented"
    end

    def to_a
      @ops.map(&:to_h)
    end

    private

    def ensure_pointer(path, op, index)
      # TODO:
      raise "Not Implemented"
    end
  end
end
