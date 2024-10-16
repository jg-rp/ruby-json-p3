# frozen_string_literal: true

require_relative "jsonpath_rfc9535/version"
require_relative "jsonpath_rfc9535/environment"

# RFC 9535 JSONPath query expressions for JSON.
module JsonpathRfc9535
  DefaultEnvironment = JSONPathEnvironment.new

  def self.main
    path = DefaultEnvironment.compile("$[?@.a]")
    puts path
    data = [{ "a" => "b", "d" => "e" }, { "b" => "c", "d" => "f" }]
    nodes = path.find(data)
    puts "==", nodes.inspect, "=="
  end
end
