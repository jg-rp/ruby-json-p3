# frozen_string_literal: true

require_relative "../cache"
require_relative "../function"
require_relative "pattern"

module JSONP3
  # The standard `search` function.
  class Search < FunctionExtension
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
        re = @cache[pattern] || Regexp.new(JSONP3.map_iregexp(pattern))
      else
        re = Regexp.new(JSONP3.map_iregexp(pattern))
        @cache[pattern] = re
      end

      re.match?(value)
    rescue RegexpError
      raise if @raise_errors

      false
    end
  end
end
