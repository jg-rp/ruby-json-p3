# frozen_string_literal: true

require "English"

module JSONP3
  # A JSON Patch containing zero or more patch operations.
  class Patch
    def self.apply(ops, value)
      new(ops).apply(value)
    end

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
          raise Patch::Error,
                "expected 'op' to be one of 'add', 'remove', 'replace', 'move', 'copy' or 'test' (#{obj["op"]}:#{i})"
        end
      end
    end

    def op_pointer(obj, key, op, index)
      raise Patch::Error, "missing property '#{key}' (#{op}:#{index})" unless obj.key?(key)

      JSONP3::Pointer.new(obj[key])
    rescue Pointer::Error
      raise Patch::Error, "#{$ERROR_INFO} (#{op}:#{index})"
    end

    def op_value(obj, key, op, index)
      raise Patch::Error, "missing property '#{key}' (#{op}:#{index})" unless obj.key?(key)

      obj[key]
    end

    def ensure_pointer(pointer, op, index)
      return pointer unless pointer.is_a?(String)

      JSONP3::Pointer.new(pointer)
    rescue Pointer::Error
      raise Patch::Error, "#{$ERROR_INFO} (#{op}:#{index})"
    end
  end
end
