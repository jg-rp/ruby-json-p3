# frozen_string_literal: true

require "benchmark/ips"
require "json"
require "jsonpath_rfc9535"

CTS = JSON.parse(File.read("test/cts/cts.json"))
VALID_QUERIES = CTS["tests"].filter { |t| !t.key?("invalid_selector") }
COMPILED_QUERIES = VALID_QUERIES.map { |t| [JSONPathRFC9535.compile(t["selector"]), t["document"]] }

puts "#{VALID_QUERIES.length} queries per iteration"

Benchmark.ips do |x|
  # Configure the number of seconds used during
  # the warmup phase (default 2) and calculation phase (default 5)
  x.config(warmup: 2, time: 5)

  x.report("compile and find:") do
    VALID_QUERIES.map { |t| JSONPathRFC9535.find(t["selector"], t["document"]) }
  end

  x.report("just compile:") do
    VALID_QUERIES.map { |t| JSONPathRFC9535.compile(t["selector"]) }
  end

  x.report("just find:") do
    COMPILED_QUERIES.map { |p, d| p.find(d) }
  end
end
