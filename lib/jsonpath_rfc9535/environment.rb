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
  class JSONPathEnvironment
    attr_reader :function_extensions

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
    # @param query [String]
    # @param value [JSON-like data]
    # @return [Array<JSONPath>]
    def find(query, value)
      compile(query).find(value)
    end

    def setup_function_extensions
      @function_extensions["length"] = Length.new
      @function_extensions["count"] = Count.new
      @function_extensions["value"] = Value.new
      @function_extensions["match"] = Match.new
      @function_extensions["search"] = Search.new
    end
  end
end
