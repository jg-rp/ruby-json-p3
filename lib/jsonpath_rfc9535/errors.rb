# frozen_string_literal: true

module JSONPathRFC9535
  # Base class for all JSONPath exceptions
  class JSONPathError < StandardError
    def initialize(msg, token)
      super(msg)
      @token = token
    end
  end

  class JSONPathSyntaxError < JSONPathError; end
  class JSONPathTypeError < JSONPathError; end
  class JSONPathNameError < JSONPathError; end
end
