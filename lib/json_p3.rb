# frozen_string_literal: true

require_relative "json_p3/version"
require_relative "json_p3/environment"
require_relative "json_p3/pointer"
require_relative "json_p3/patch"

# RFC 9535 JSONPath query expressions for JSON.
module JSONP3
  DefaultEnvironment = JSONPathEnvironment.new

  def self.find(path, data)
    DefaultEnvironment.find(path, data)
  end

  def self.find_enum(path, data)
    DefaultEnvironment.find_enum(path, data)
  end

  def self.compile(path)
    DefaultEnvironment.compile(path)
  end

  def self.match(path, data)
    DefaultEnvironment.match(path, data)
  end

  def self.match?(path, data)
    DefaultEnvironment.match?(path, data)
  end

  def self.first(path, data)
    DefaultEnvironment.first(path, data)
  end

  def self.resolve(pointer, value, default: JSONPointer::UNDEFINED)
    JSONPointer.new(pointer).resolve(value, default: default)
  end

  def self.apply(ops, value)
    JSONPatch.new(ops).apply(value)
  end
end
