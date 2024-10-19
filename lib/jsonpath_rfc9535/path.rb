# frozen_string_literal: true

require_relative "node"

module JSONPathRFC9535
  # A compiled JSONPath expression ready to be applied to JSON-like values.
  class JSONPath
    def initialize(env, segments)
      @env = env
      @segments = segments
    end

    def to_s
      "$#{@segments.map(&:to_s).join}"
    end

    # Apply this JSONPath expression to JSON-like value _root_.
    # @param root [Array, Hash, String, Integer] the root JSON-like value to apply this query to.
    # @return [Array<JSONPathNode>] the sequence of nodes found while applying this query to _root_.
    def find(root)
      nodes = [JSONPathNode.new(root, [], root)]
      @segments.each { |segment| nodes = segment.resolve(nodes) }
      JSONPathNodeList.new(nodes) # TODO: avoid new?
    end

    alias apply find

    # Return true if this JSONPath expression is a singular query.
    def singular?
      @segments.each do |segment|
        return false if segment.instance_of? RecursiveDescentSegment
        return false unless segment.selectors.length == 1 && segment.selectors[0].singular?
      end
      true
    end

    # Return true if this JSONPath expression has no segments.
    def empty?
      @segments.empty?
    end
  end
end
