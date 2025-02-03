# frozen_string_literal: true

require "json"
require "test_helper"

class TestCompliance < Minitest::Spec
  make_my_diffs_pretty!

  cts = JSON.parse(File.read("test/cts/cts.json"))

  describe "compliance" do
    cts["tests"].each do |test_case|
      it test_case["name"] do
        if test_case.key? "result"
          nodes = JSONP3.find(test_case["selector"], test_case["document"])
          _(nodes.map(&:value)).must_equal(test_case["result"])
        elsif test_case.key? "results"
          nodes = JSONP3.find(test_case["selector"], test_case["document"])
          _(test_case["results"]).must_include(nodes.map(&:value))
        elsif test_case.key? "invalid_selector"
          assert_raises JSONP3::JSONPathError do
            JSONP3.compile(test_case["selector"])
          end
        end
      end
    end
  end

  describe "compliance enum" do
    cts["tests"].each do |test_case|
      it test_case["name"] do
        if test_case.key? "result"
          enum = JSONP3.find_enum(test_case["selector"], test_case["document"])
          nodes = enum.to_a
          _(nodes.map(&:value)).must_equal(test_case["result"])
        elsif test_case.key? "results"
          enum = JSONP3.find_enum(test_case["selector"], test_case["document"])
          nodes = enum.to_a
          _(test_case["results"]).must_include(nodes.map(&:value))
        elsif test_case.key? "invalid_selector"
          assert_raises JSONP3::JSONPathError do
            JSONP3.compile(test_case["selector"])
          end
        end
      end
    end
  end
end
