# frozen_string_literal: true

require "benchmark"
require "json"
require "json_p3"

# TODO: include small-citylots.json as a git submodule
DATA = JSON.parse(File.read("/tmp/small-citylots.json")).freeze

Benchmark.bm(15) do |x|
  x.report("deep:") do
    JSONP3.find("$.features..properties.BLOCK_NUM", DATA)
  end

  x.report("shallow:") do
    JSONP3.find("$.features..properties", DATA)
  end

  x.report("enum deep:") do
    JSONP3.find_enum("$.features..properties.BLOCK_NUM", DATA).to_a
  end

  x.report("enum shallow:") do
    JSONP3.find_enum("$.features..properties", DATA).to_a
  end
end
