# frozen_string_literal: true

require "memory_profiler"
require "json"
require "json_p3"

CTS = JSON.parse(File.read("test/cts/cts.json"))
VALID_QUERIES = CTS["tests"].filter { |t| !t.key?("invalid_selector") }
COMPILED_QUERIES = VALID_QUERIES.map { |t| [JSONP3.compile(t["selector"]), t["document"]] }

n = 10

report = MemoryProfiler.report do
  n.times do
    VALID_QUERIES.map { |t| JSONP3.compile(t["selector"]) }
  end
end

report.pretty_print
