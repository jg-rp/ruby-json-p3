# frozen_string_literal: true

require "json"
require "test_helper"

class TestCompliance < Minitest::Spec
  make_my_diffs_pretty!
  i_suck_and_my_tests_are_order_dependent!

  cts = JSON.parse(File.read("test/cts/cts.json"))

  describe "compliance" do
    cts["tests"].each do |test_case|
      it test_case["name"] do
        if test_case.key? "result"
          nodes = JSONPathRFC9535.find(test_case["selector"], test_case["document"])
          _(nodes.map(&:value)).must_equal(test_case["result"])
        elsif test_case.key? "results"
          nodes = JSONPathRFC9535.find(test_case["selector"], test_case["document"])
          _(test_case["results"]).must_include(nodes.map(&:value))
        elsif test_case.key? "invalid_selector"
          assert_raises JSONPathRFC9535::JSONPathError do
            JSONPathRFC9535.compile(test_case["selector"])
          end
        end
      end
    end
  end
end
