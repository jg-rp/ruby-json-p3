# frozen_string_literal: true

require "benchmark"
require "json"
require "jsonpath_rfc9535"

CTS = JSON.parse(File.read("test/cts/cts.json"))
VALID_QUERIES = CTS["tests"].filter { |t| t.key?("result") }
COMPILED_QUERIES = VALID_QUERIES.map { |t| [JSONPathRFC9535.compile(t["selector"]), t["document"]] }

n = 100
Benchmark.bm(18) do |x|
  x.report("compile and find:") do
    n.times do
      VALID_QUERIES.map { |t| JSONPathRFC9535.find(t["selector"], t["document"]) }
    end
  end

  x.report("just compile:") do
    n.times do
      VALID_QUERIES.map { |t| JSONPathRFC9535.compile(t["selector"]) }
    end
  end

  x.report("just find:") do
    n.times do
      COMPILED_QUERIES.map { |p, d| p.find(d) }
    end
  end
end
