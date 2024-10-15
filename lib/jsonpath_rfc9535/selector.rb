# frozen_string_literal: true

module JsonpathRfc9535
  # Base class for all JSONPath selectors
  class Selector
    # @dynamic token
    attr_reader :token

    def initialize(env, token)
      @env = env
      @token = token
    end

    # Apply this selector to _node_.
    def resolve(_node)
      raise "selectors must implement resolve(node)"
    end
  end

  # The name selector select values from hashes given a key.
  class NameSelector < Selector
    # @dynamic name
    attr_reader :name

    def initialize(env, token, name)
      super(env, token)
      @name = name
    end

    def resolve(node)
      [node.new_child(node.value.fetch(@name), @name)]
    rescue StandardError
      []
    end

    def to_s
      "'#{@name}'"
    end

    def ==(other)
      self.class == other.class &&
        @name == other.name &&
        @token == other.token
    end

    alias eql? ==

    def hash
      @name.hash ^ @token.hash
    end
  end

  # The index selector selects values from arrays given an index.
  class IndexSelector < Selector
    # @dynamic index
    attr_reader :index

    def initialize(env, token, index)
      super(env, token)
      @index = index
    end

    def resolve(node)
      [node.new_child(node.value.fetch(@index), @index)]
    rescue StandardError
      []
    end

    def to_s
      @index.to_s
    end

    def ==(other)
      self.class == other.class &&
        @index == other.index &&
        @token == other.token
    end

    alias eql? ==

    def hash
      @index.hash ^ @token.hash
    end
  end

  # The wildcard selector selects all elements from an array or values from a hash.
  class WildcardSelector < Selector
    def resolve(node)
      if node.value.is_a? Hash
        node.value.map { |k, v| node.new_child(v, k) }
      elsif node.value.is_a? Array
        node.value.map.with_index { |e, i| node.new_child(e, i) }
      else
        []
      end
    end

    def to_s
      "*"
    end

    def ==(other)
      self.class == other.class && @token == other.token
    end

    alias eql? ==

    def hash
      @token.hash
    end
  end

  # The slice selector selects a range of elements from an array.
  class SliceSelector < Selector
    # @dynamic start, stop, step
    attr_reader :start, :stop, :step

    def initialize(env, token, start, stop, step)
      super(env, token)
      @start = start
      @stop = stop
      @step = step
    end

    def resolve(node)
      return [] unless node.value.is_a?(Array) || @step.zero?

      # TODO: cap stop and step? or does zip cover this?
      length = node.value.length
      indicies = stop.nil? ? (start || 0...length).step(step || 1) : (start || 0...stop).step(step || 1)
      indicies.to_a.zip(node.value[indicies]).map do |i, v|
        node.new_child(v, i.negative? && length >= i.abs ? length + i : i)
      end
    end

    def to_s
      start = @start || ""
      stop = @stop || ""
      step = @step || 1
      "#{start}:#{stop}:#{step}"
    end

    def ==(other)
      self.class == other.class &&
        @start == other.start &&
        @stop == other.stop &&
        @step == other.step &&
        @token == other.token
    end

    alias eql? ==

    def hash
      @start.hash ^ @stop.hash ^ @step.hash ^ @token.hash
    end
  end

  # TODO: FilterSelector
  # TODO: Define node
end
