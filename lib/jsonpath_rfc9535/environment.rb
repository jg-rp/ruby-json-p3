# frozen_string_literal: true

require_relative "lexer"
require_relative "parser"
require_relative "path"

module JSONPathRFC9535
  # JSONPath configuration
  class JSONPathEnvironment
    def initialize
      @parser = Parser.new(self)
      @function_extensions = {}
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
  end
end
