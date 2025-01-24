# frozen_string_literal: true

require "json"
require "test_helper"

class TestNormalizedPathTestSuite < Minitest::Spec
  make_my_diffs_pretty!

  nts = JSON.parse(File.read("test/nts/normalized_paths.json"))

  describe "normalized path test suite" do
    nts["tests"].each do |test_case|
      it test_case["name"] do
        nodes = JSONP3.find(test_case["query"], test_case["document"])
        paths = nodes.map(&:path)
        _(paths).must_equal(test_case["paths"])
      end
    end
  end
end

class TestCanonicalPathTestSuite < Minitest::Spec
  make_my_diffs_pretty!

  nts = JSON.parse(File.read("test/nts/canonical_paths.json"))

  describe "canonical path test suite" do
    nts["tests"].each do |test_case|
      it test_case["name"] do
        query = JSONP3.compile(test_case["query"])
        path = query.to_s
        _(path).must_equal(test_case["canonical"])
      end
    end
  end
end
