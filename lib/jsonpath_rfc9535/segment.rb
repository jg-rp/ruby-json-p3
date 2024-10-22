# frozen_string_literal: true

module JSONPathRFC9535
  # Base class for all JSONPath segments.
  class Segment
    # @dynamic token, selectors
    attr_reader :token, :selectors

    def initialize(env, token, selectors)
      @env = env
      @token = token
      @selectors = selectors
    end

    # Select the children of each node in _nodes_.
    def resolve(_nodes)
      raise "segments must implement resolve(nodes)"
    end
  end

  # The child selection segment.
  class ChildSegment < Segment
    def resolve(nodes)
      rv = []
      nodes.each do |node|
        @selectors.each do |selector|
          rv.concat selector.resolve(node)
        end
      end
      rv
    end

    def to_s
      "[#{@selectors.map(&:to_s).join(", ")}]"
    end

    def ==(other)
      self.class == other.class &&
        @selectors == other.selectors &&
        @token == other.token
    end

    alias eql? ==

    def hash
      [@selectors, @token].hash
    end
  end

  # The recursive descent segment
  class RecursiveDescentSegment < Segment
    def resolve(nodes)
      rv = []
      nodes.each do |node|
        visit(node).each do |descendant|
          @selectors.each do |selector|
            rv.concat selector.resolve(descendant)
          end
        end
      end
      rv
    end

    def to_s
      "..[#{@selectors.map(&:to_s).join(", ")}]"
    end

    def ==(other)
      self.class == other.class &&
        @selectors == other.selectors &&
        @token == other.token
    end

    alias eql? ==

    def hash
      ["..", @selectors, @token].hash
    end

    protected

    def visit(node, depth = 1) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      raise JSONPathRecursionError.new("recursion limit exceeded", @token) if depth > @env.class::MAX_RECURSION_DEPTH

      rv = [node]

      if node.value.is_a? Array
        node.value.each_with_index do |value, i|
          child = JSONPathNode.new(value, [node.location, i], node.root)
          rv.concat visit(child, depth + 1)
        end
      elsif node.value.is_a? Hash
        node.value.each do |key, value|
          child = JSONPathNode.new(value, [node.location, key], node.root)
          rv.concat visit(child, depth + 1)
        end
      end

      rv
    end
  end
end
