# frozen_string_literal: true

module JSONPathRFC9535
  # A least recently used cache relying on Ruby hash insertion order.
  class LRUCache
    attr_reader :max_size

    def initialize(max_size = 128)
      @data = {}
      @max_size = max_size
    end

    # Return the cached value or nil if _key_ does not exist.
    def [](key)
      val = @data.fetch(key)
      @data.delete(key)
      @data[key] = val
      val
    rescue KeyError
      nil
    end

    def []=(key, value)
      if @data.key?(key)
        @data.delete(key)
      elsif @data.length >= @max_size
        @data.delete(@data.first[0])
      end
      @data[key] = value
    end

    def length
      @data.length
    end

    def keys
      @data.keys
    end
  end
end
