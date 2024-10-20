# frozen_string_literal: true

require "memory_profiler"
require "json"
require "jsonpath_rfc9535"

CTS = JSON.parse(File.read("test/cts/cts.json"))
VALID_QUERIES = CTS["tests"].filter { |t| !t.key?("invalid_selector") }
COMPILED_QUERIES = VALID_QUERIES.map { |t| [JSONPathRFC9535.compile(t["selector"]), t["document"]] }

n = 100

report = MemoryProfiler.report do
  n.times do
    VALID_QUERIES.map { |t| JSONPathRFC9535.compile(t["selector"]) }
  end
end

report.pretty_print
