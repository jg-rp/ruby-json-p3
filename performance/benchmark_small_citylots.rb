# frozen_string_literal: true

require "benchmark"
require "json"
require "jsonpath_rfc9535"

# TODO: include small-citylots.json as a git submodule
DATA = JSON.parse(File.read("/tmp/small-citylots.json")).freeze

Benchmark.bm(15) do |x|
  x.report("deep:") do
    JSONPathRFC9535.find("$.features..properties.BLOCK_NUM", DATA)
  end

  x.report("shallow:") do
    JSONPathRFC9535.find("$.features..properties", DATA)
  end
end
