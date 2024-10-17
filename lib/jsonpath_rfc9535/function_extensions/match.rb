# frozen_string_literal: true

require "iregexp"
gem_dir = Gem::Specification.find_by_name("iregexp").gem_dir
require "#{gem_dir}/lib/writer/iregexp-writer.rb" # XXX

require_relative "../function"

module JSONPathRFC9535
  # The standard `count` function.
  class Match < FunctionExtension
    ARG_TYPES = [ExpressionType::VALUE, ExpressionType::VALUE].freeze
    RETURN_TYPE = ExpressionType::LOGICAL

    def call(string, pattern)
      return false unless pattern.is_a? String

      ire = IREGEXP.from_iregexp(pattern)
      pcre = Regex.new(ire.to_pcre)
      pcre.match?(string)
    rescue IREGEXP.ParserError
      false
    end
  end
end
