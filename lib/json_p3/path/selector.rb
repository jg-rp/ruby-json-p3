# frozen_string_literal: true

module JSONP3
  module Path
    # Base class for all JSONPath selectors
    class Selector
      attr_reader :token

      def initialize(env, token)
        @env = env
        @token = token
      end

      # Apply this selector to _node_.
      # @return [Array<Node>]
      def resolve(_node)
        raise "selectors must implement resolve(node)"
      end

      # Apply this selector to _node_.
      # @return [Enumerable<Node>]
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
        JSONP3::Path.canonical_string(@name)
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

        if step.positive?
          norm_start = normalized_index(@start, 0, length, @step)
          norm_end = normalized_index(@stop, length, length, @step)
        else
          norm_start = normalized_index(@start, length - 1, length, @step)
          norm_end = normalized_index(@stop, -1, length, @step)
        end

        (norm_start...norm_end).step(@step).map { |i| node.new_child(node.value[i], i) }
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

      private

      #: (Integer?, Integer, Integer, Integer) -> Integer
      def normalized_index(num, default, length, step)
        return default if num.nil?

        if num.negative?
          return step.negative? ? [num + length, -1].max : [num + length, 0].max
        end

        step.negative? ? [num, length - 1].min : [num, length].min
      end
    end

    # Select array elements or hash values according to a filter expression.
    class FilterSelector < Selector
      attr_reader :expression

      def initialize(env, token, expression)
        super(env, token)
        @expression = expression
      end

      def resolve(node)
        # @type var nodes: Array[Node]
        nodes = []

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
end
