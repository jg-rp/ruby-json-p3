# frozen_string_literal: true

module JsonpathRfc9535
  class JSONPathError < StandardError
    def initialize(msg, token)
      super(msg)
      @token = token
    end
  end

  class JSONPathSyntaxError < JSONPathError; end
  class JSONPathTypeError < JSONPathError; end
end
