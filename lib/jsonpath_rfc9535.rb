# frozen_string_literal: true

require_relative "jsonpath_rfc9535/version"
require_relative "jsonpath_rfc9535/environment"

# RFC 9535 JSONPath query expressions for JSON.
module JsonpathRfc9535
  DefaultEnvironment = JSONPathEnvironment.new

  def self.main
    path = DefaultEnvironment.compile("$.foo.*")
    puts path
    nodes = path.find({ "foo" => { "bar" => 42, "baz" => 7 } })
    puts nodes
  end
end
