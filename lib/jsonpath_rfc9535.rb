# frozen_string_literal: true

require_relative "jsonpath_rfc9535/version"
require_relative "jsonpath_rfc9535/lexer"

# RFC 9535 JSONPath query expressions for JSON.
module JsonpathRfc9535
  def self.main
    l = Lexer.new("$[?count(@.foo)>2]")
    l.run
    puts l.tokens.pretty_inspect
  end
end
