# frozen_string_literal: true

require "test_helper"

class TestCompliance < Minitest::Spec
  make_my_diffs_pretty!

  RFC6901_DOCUMENT = {
    "foo" => %w[bar baz],
    "" => 0,
    "a/b" => 1,
    "c%d" => 2,
    "e^f" => 3,
    "g|h" => 4,
    "i\\j" => 5,
    'k"l' => 6,
    " " => 7,
    "m~n" => 8
  }.freeze

  TEST_CASES = [
    { "pointer" => "", "want" => RFC6901_DOCUMENT },
    { "pointer" => "/foo", "want" => %w[bar baz] },
    { "pointer" => "/foo/0", "want" => "bar" },
    { "pointer" => "/", "want" => 0 },
    { "pointer" => "/a~1b", "want" => 1 },
    { "pointer" => "/c%d", "want" => 2 },
    { "pointer" => "/e^f", "want" => 3 },
    { "pointer" => "/g|h", "want" => 4 },
    { "pointer" => "/i\\j", "want" => 5 },
    { "pointer" => '/k"l', "want" => 6 },
    { "pointer" => "/ ", "want" => 7 },
    { "pointer" => "/m~0n", "want" => 8 }
  ].freeze

  describe "RFC6901" do
    TEST_CASES.each_with_index do |test_case, i|
      it i.to_s do
        p = JSONP3::JSONPointer.new(test_case["pointer"])
        _(p.resolve(RFC6901_DOCUMENT)).must_equal(test_case["want"])
      end
    end
  end
end
