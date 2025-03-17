# frozen_string_literal: true

require "test_helper"

class TestErrors < Minitest::Test
  def test_issue22
    assert_instance_of(JSONP3::JSONPath, JSONP3.compile("$[? count(@.likes[? @.location]) > 3]"))
  end
end
