# frozen_string_literal: true

require_relative "../cache"
require_relative "../function"
require_relative "pattern"

module JSONP3
  # The standard `match` function.
  class Match < FunctionExtension
    ARG_TYPES = %i[value_expression value_expression].freeze
    RETURN_TYPE = :logical_expression

    # @param cache_size [Integer] the maximum size of the regexp cache. Set it to
    #   zero or negative to disable the cache.
    # @param raise_errors [Boolean] if _false_ (the default), return _false_ when this
    #   function causes a RegexpError instead of raising the exception.
    def initialize(cache_size = 128, raise_errors: false)
      super()
      @cache_size = cache_size
      @raise_errors = raise_errors
      @cache = LRUCache.new(cache_size)
    end

    # @param value [String]
    # @param pattern [String]
    # @return Boolean
    def call(value, pattern)
      return false unless pattern.is_a?(String) && value.is_a?(String)

      if @cache_size.positive?
        re = @cache[pattern] || Regexp.new(full_match(pattern))
      else
        re = Regexp.new(full_match(pattern))
        @cache[pattern] = re
      end

      re.match?(value)
    rescue RegexpError
      raise if @raise_errors

      false
    end

    private

    def full_match(pattern)
      parts = []
      explicit_caret = pattern.start_with?("^")
      explicit_dollar = pattern.end_with?("$")

      # Replace '^' with '\A' and '$' with '\z'
      pattern = pattern.sub("^", "\\A") if explicit_caret
      pattern = "#{pattern[..-1]}\\z" if explicit_dollar

      # Wrap with '\A' and '\z' if they are not already part of the pattern.
      parts << "\\A(?:" if !explicit_caret && !explicit_dollar
      parts << JSONP3.map_iregexp(pattern)
      parts << ")\\z" if !explicit_caret && !explicit_dollar
      parts.join
    end
  end
end
