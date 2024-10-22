# frozen_string_literal: true

require_relative "lexer"
require_relative "parser"
require_relative "path"
require_relative "function_extensions/length"
require_relative "function_extensions/value"
require_relative "function_extensions/count"
require_relative "function_extensions/match"
require_relative "function_extensions/search"

module JSONPathRFC9535
  # JSONPath configuration
  #
  # You are encouraged to configure your environment by subclassing `JSONPathEnvironment`
  # and setting one or more constants or overriding {setup_function_extensions}.
  class JSONPathEnvironment
    # The maximum integer allowed when selecting array items by index.
    MAX_INT_INDEX = (2**53) - 1

    # The minimum integer allowed when selecting array items by index.
    MIN_INT_INDEX = -(2**53) + 1

    # The maximum number of arrays and hashes the recursive descent segment
    # will traverse before raising a {JSONPathRecursionError}.
    MAX_RECURSION_DEPTH = 100

    # When _true_ replaces the default _name selector_ with a name selector
    # that will resolve hashes with symbol keys as well as string keys.
    SYMBOL_SELECTOR = false

    attr_accessor :function_extensions

    def initialize
      @parser = Parser.new(self)
      @function_extensions = {}
      setup_function_extensions
    end

    # Prepare JSONPath expression _query_ for repeated application.
    # @param query [String]
    # @return [JSONPath]
    def compile(query)
      tokens = JSONPathRFC9535.tokenize(query)
      JSONPath.new(self, @parser.parse(tokens))
    end

    # Apply JSONPath expression _query_ to _value_.
    # @param query [String] the JSONPath expression
    # @param value [JSON-like data] the target JSON "document"
    # @return [Array<JSONPath>]
    def find(query, value)
      compile(query).find(value)
    end

    # Override this function to configure JSONPath function extensions.
    # By default, only the standard functions described in RFC 9535 are enabled.
    def setup_function_extensions
      @function_extensions["length"] = Length.new
      @function_extensions["count"] = Count.new
      @function_extensions["value"] = Value.new
      @function_extensions["match"] = Match.new
      @function_extensions["search"] = Search.new
    end
  end
end
