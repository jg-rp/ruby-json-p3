# frozen_string_literal: true

module JSONP3
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
      Enumerator.new do |yielder|
        nodes.each do |node|
          @selectors.each do |selector|
            selector.resolve(node).each do |item|
              yielder << item
            end
          end
        end
      end
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
      Enumerator.new do |yielder|
        nodes.each do |node|
          visit(node).each do |descendant|
            @selectors.each do |selector|
              selector.resolve(descendant).each do |item|
                yielder << item
              end
            end
          end
        end
      end
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

    def visit(node, depth = 1)
      raise JSONPathRecursionError.new("recursion limit exceeded", @token) if depth > @env.class::MAX_RECURSION_DEPTH

      Enumerator.new do |yielder|
        yielder << node
        if node.value.is_a? Array
          node.value.each_with_index do |value, i|
            child = JSONPathNode.new(value, [node.location, i], node.root)
            visit(child, depth + 1).each do |item|
              yielder << item
            end
          end
        elsif node.value.is_a? Hash
          node.value.each do |key, value|
            child = JSONPathNode.new(value, [node.location, key], node.root)
            visit(child, depth + 1).each do |item|
              yielder << item
            end
          end
        end
      end
    end
  end
end
