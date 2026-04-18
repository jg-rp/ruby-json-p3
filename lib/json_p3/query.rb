# frozen_string_literal: true

require_relative "node"

module JSONP3
  module Path
    # A compiled JSONPath expression ready to be applied to JSON-like values.
    class Query
      def initialize(env, segments)
        @env = env
        @segments = segments
      end

      def to_s
        "$#{@segments.map(&:to_s).join}"
      end

      # Apply this JSONPath expression to JSON-like value _root_.
      # @param root [Array, Hash, String, Integer, nil] the root JSON-like value to apply this query to.
      # @return [Array<Node>] the sequence of nodes found while applying this query to _root_.
      def find(root)
        nodes = [Node.new(root, [], root)]
        @segments.each { |segment| nodes = segment.resolve(nodes) }
        NodeList.new(nodes) # TODO: use NodeList internally?
      end

      alias apply find

      # Apply this JSONPath expression to JSON-like value _root_.
      # @param root [Array, Hash, String, Integer, nil] the root JSON-like value to apply this query to.
      # @return [Enumerable<Node>] the sequence of nodes found while applying this query to _root_.
      def find_enum(root)
        nodes = [Node.new(root, [], root)] # : Enumerable[Node]
        @segments.each { |segment| nodes = segment.resolve_enum(nodes) }
        nodes
      end

      # Return the first node from applying this JSONPath expression to JSON-like value _root_.
      # @param root [Array, Hash, String, Integer, nil] the root JSON-like value to apply this query to.
      # @return [Node | nil] the first available node or nil if there were no matches.
      def match(root)
        find_enum(root).first
      end

      # Return `true` if this query results in at least one node, or `false` otherwise.
      # @param root [Array, Hash, String, Integer, nil] the root JSON-like value to apply this query to.
      # @return [bool] `true` if this query results in at least one node, or `false` otherwise.
      def match?(root)
        !find_enum(root).first.nil?
      end

      # Return the first node from applying this JSONPath expression to JSON-like value _root_.
      # @param root [Array, Hash, String, Integer, nil] the root JSON-like value to apply this query to.
      # @return [Node | nil] the first available node or nil if there were no matches.
      def first(root)
        find_enum(root).first
      end

      # Return _true_ if this JSONPath expression is a singular query.
      def singular?
        @segments.each do |segment|
          return false if segment.instance_of? DescendantSegment
          return false unless segment.selectors.length == 1 && segment.selectors[0].singular?
        end
        true
      end

      # Return _true_ if this JSONPath expression has no segments.
      def empty?
        @segments.empty?
      end
    end
  end
end
