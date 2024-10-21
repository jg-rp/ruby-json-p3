# frozen_string_literal: true

require "memory_profiler"
require "json"
require "jsonpath_rfc9535"

# TODO: include small-citylots.json as a git submodule
DATA = JSON.parse(File.read("/tmp/small-citylots.json")).freeze

report = MemoryProfiler.report do
  JSONPathRFC9535.find("$.features..properties", DATA)
end

report.pretty_print
