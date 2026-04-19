# frozen_string_literal: true

require_relative "json_p3/version"
require_relative "json_p3/errors"
require_relative "json_p3/cache"
require_relative "json_p3/path/environment"
require_relative "json_p3/pointer"
require_relative "json_p3/relative_pointer"
require_relative "json_p3/patch"
require_relative "json_p3/patch/op"
require_relative "json_p3/patch/op_add"
require_relative "json_p3/patch/op_copy"
require_relative "json_p3/patch/op_move"
require_relative "json_p3/patch/op_remove"
require_relative "json_p3/patch/op_replace"
require_relative "json_p3/patch/op_test"

# JSONPath, JSON Pointer and JSONPatch.
module JSONP3
  # JSONPath query expressions.
  module Path
    DefaultEnvironment = JSONP3::Path::Environment.new

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
  end

  def self.find(path, data)
    Path.find(path, data)
  end

  def self.find_enum(path, data)
    Path.find_enum(path, data)
  end

  def self.compile(path)
    Path.compile(path)
  end

  def self.match(path, data)
    Path.match(path, data)
  end

  def self.match?(path, data)
    Path.match?(path, data)
  end

  def self.first(path, data)
    Path.first(path, data)
  end

  def self.resolve(pointer, value, default: Pointer::UNDEFINED)
    Pointer.resolve(pointer, value, default: default)
  end

  def self.apply(ops, value)
    Patch.apply(ops, value)
  end
end
