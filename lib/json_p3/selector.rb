# frozen_string_literal: true

module JSONP3
  # Base class for all JSONPath selectors
  class Selector
    # @dynamic token
    attr_reader :token

    def initialize(env, token)
      @env = env
      @token = token
    end

    # Apply this selector to _node_.
    # @return [Array<JSONPathNode>]
    def resolve(_node)
      raise "selectors must implement resolve(node)"
    end

    # Apply this selector to _node_.
    # @return [Enumerable<JSONPathNode>]
    def resolve_enum(node)
      resolve(node)
    end

    # Return true if this selector is a singular selector.
    def singular?
      false
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
      if node.value.is_a?(Hash) && node.value.key?(@name)
        [node.new_child(node.value[@name], @name)]
      else
        []
      end
    end

    def singular?
      true
    end

    def to_s
      JSONP3.canonical_string(@name)
    end

    def ==(other)
      self.class == other.class &&
        @name == other.name &&
        @token == other.token
    end

    alias eql? ==

    def hash
      [@name, @token].hash
    end
  end

  # This non-standard name selector selects values from hashes given a string or
  # symbol key.
  class SymbolNameSelector < NameSelector
    def initialize(env, token, name)
      super
      @sym = @name.to_sym
    end

    def resolve(node)
      if node.value.is_a?(Hash)
        if node.value.key?(@name)
          [node.new_child(node.value[@name], @name)]
        elsif node.value.key?(@sym)
          [node.new_child(node.value[@sym], @name)]
        else
          []
        end
      else
        []
      end
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
      if node.value.is_a?(Array)
        norm_index = normalize(@index, node.value.length)
        return [] if norm_index.negative? || norm_index >= node.value.length

        [node.new_child(node.value[@index], norm_index)]
      else
        []
      end
    end

    def singular?
      true
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
      [@index, @token].hash
    end

    private

    def normalize(index, length)
      index.negative? && length >= index.abs ? length + index : index
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

    def resolve_enum(node)
      if node.value.is_a? Hash
        Enumerator.new do |yielder|
          node.value.each do |k, v|
            yielder << node.new_child(v, k)
          end
        end
      elsif node.value.is_a? Array
        Enumerator.new do |yielder|
          node.value.each.with_index do |e, i|
            yielder << node.new_child(e, i)
          end
        end
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
      @step = step || 1
    end

    def resolve(node)
      return [] unless node.value.is_a?(Array)

      length = node.value.length
      return [] if length.zero? || @step.zero?

      normalized_start = if @start.nil?
                           @step.negative? ? length - 1 : 0
                         elsif @start&.negative?
                           [length + (@start || raise), 0].max
                         else
                           [@start || raise, length - 1].min
                         end

      normalized_stop = if @stop.nil?
                          @step.negative? ? -1 : length
                        elsif @stop&.negative?
                          [length + (@stop || raise), -1].max
                        else
                          [@stop || raise, length].min
                        end

      (normalized_start...normalized_stop).step(@step).map { |i| node.new_child(node.value[i], i) }
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
      [@start, @stop, @step, @token].hash
    end
  end

  # Select array elements or hash values according to a filter expression.
  class FilterSelector < Selector
    # @dynamic expression
    attr_reader :expression

    def initialize(env, token, expression)
      super(env, token)
      @expression = expression
    end

    def resolve(node)
      nodes = [] # : Array[JSONPathNode]

      if node.value.is_a?(Array)
        node.value.each_with_index do |e, i|
          context = FilterContext.new(@env, e, node.root)
          nodes << node.new_child(e, i) if @expression.evaluate(context)
        end
      elsif node.value.is_a?(Hash)
        node.value.each_pair do |k, v|
          context = FilterContext.new(@env, v, node.root)
          nodes << node.new_child(v, k) if @expression.evaluate(context)
        end
      end

      nodes
    end

    def resolve_enum(node)
      Enumerator.new do |yielder|
        if node.value.is_a?(Array)
          node.value.each_with_index do |e, i|
            context = FilterContext.new(@env, e, node.root)
            yielder << node.new_child(e, i) if @expression.evaluate(context)
          end
        elsif node.value.is_a?(Hash)
          node.value.each_pair do |k, v|
            context = FilterContext.new(@env, v, node.root)
            yielder << node.new_child(v, k) if @expression.evaluate(context)
          end
        end
      end
    end

    def to_s
      "?#{@expression}"
    end

    def ==(other)
      self.class == other.class &&
        @expression == other.start &&
        @token == other.token
    end

    alias eql? ==

    def hash
      [@expression, @token].hash
    end
  end
end
