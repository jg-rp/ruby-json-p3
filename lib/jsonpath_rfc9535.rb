# frozen_string_literal: true

require_relative "jsonpath_rfc9535/version"
require_relative "jsonpath_rfc9535/environment"

# RFC 9535 JSONPath query expressions for JSON.
module JSONPathRFC9535
  DefaultEnvironment = JSONPathEnvironment.new

  def self.find(path, data)
    DefaultEnvironment.find(path, data)
  end

  def self.compile(path)
    DefaultEnvironment.compile(path)
  end
end
