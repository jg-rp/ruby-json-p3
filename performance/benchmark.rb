# frozen_string_literal: true

require "benchmark"
require "json"
require "json_p3"

CTS = JSON.parse(File.read("test/cts/cts.json"))
VALID_QUERIES = CTS["tests"].filter { |t| !t.key?("invalid_selector") }
COMPILED_QUERIES = VALID_QUERIES.map { |t| [JSONP3.compile(t["selector"]), t["document"]] }

n = 100

puts "repeating #{VALID_QUERIES.length} queries #{n} times"

Benchmark.bmbm(18) do |x|
  x.report("compile and find:") do
    n.times do
      VALID_QUERIES.map { |t| JSONP3.find(t["selector"], t["document"]) }
    end
  end

  x.report("just compile:") do
    n.times do
      VALID_QUERIES.map { |t| JSONP3.compile(t["selector"]) }
    end
  end

  x.report("just find:") do
    n.times do
      COMPILED_QUERIES.map { |p, d| p.find(d) }
    end
  end
end
