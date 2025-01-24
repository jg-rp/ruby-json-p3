# frozen_string_literal: true

require "json"

module JSONP3 # rubocop:disable Style/Documentation
  TRANS = { "\\\"" => "\"", "'" => "\\'" }.freeze

  # Return _value_ formatted as a canonical string literal.
  # @param value [String]
  def self.canonical_string(value)
    "'#{(JSON.dump(value)[1..-2] || raise).gsub(/('|\\")/, TRANS)}'"
  end
end
