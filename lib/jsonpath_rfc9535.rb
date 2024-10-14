# frozen_string_literal: true

require_relative "jsonpath_rfc9535/version"
require_relative "jsonpath_rfc9535/lexer"

module JsonpathRfc9535
  def self.main
    l = Lexer.new("$.foo['bar']")
    l.run
    puts l.tokens.inspect
  end
end
