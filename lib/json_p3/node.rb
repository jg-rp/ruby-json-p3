# frozen_string_literal: true

require_relative "serialize"

module JSONP3
  # A JSON-like value and its location.
  class JSONPathNode
    # @dynamic value, location, root
    attr_reader :value, :location, :root

    # @param value [JSON-like] the value at this node.
    # @param location [Array<String | Integer | Array<String | Integer>>] the sequence of
    #   names and/or indices leading to _value_ in _root_.
    # @param root [JSON-like] the root value containing _value_ at _location_.
    def initialize(value, location, root)
      @value = value
      @location = location
      @root = root
    end

    # Return the normalized path to this node.
    # @return [String] the normalized path.
    def path
      segments = @location.flatten.map { |i| i.is_a?(String) ? "[#{JSONP3.canonical_string(i)}]" : "[#{i}]" }
      "$#{segments.join}"
    end

    # Return a new node that is a child of this node.
    # @param value the JSON-like value at the new node.
    # @param key [Integer, String] the array index or hash key associated with _value_.
    def new_child(value, key)
      JSONPathNode.new(value, [@location, key], @root)
    end

    def to_s
      "JSONPathNode(#{value} at #{path})"
    end
  end

  # An array of JSONPathNode instances. We use this internally to differentiate
  # arrays of Nodes and arrays of data values, which is required when calling
  # filter functions expecting nodes as arguments. It is just an array though.
  class JSONPathNodeList < Array; end
end
