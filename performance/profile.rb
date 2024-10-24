# frozen_string_literal: true

require "stackprof"

require "json"
require "json_p3"

CTS = JSON.parse(File.read("test/cts/cts.json"))
VALID_QUERIES = CTS["tests"].filter { |t| t.key?("result") }
COMPILED_QUERIES = VALID_QUERIES.map { |t| [JSONP3.compile(t["selector"]), t["document"]] }

n = 100

StackProf.run(mode: :cpu, raw: true, out: ".stackprof-cpu-compile-and-find.dump") do
  n.times do
    VALID_QUERIES.map { |t| JSONP3.find(t["selector"], t["document"]) }
  end
end

StackProf.run(mode: :cpu, raw: true, out: ".stackprof-cpu-just-compile.dump") do
  n.times do
    VALID_QUERIES.map { |t| JSONP3.compile(t["selector"]) }
  end
end

StackProf.run(mode: :cpu, raw: true, out: ".stackprof-cpu-just-find.dump") do
  n.times do
    COMPILED_QUERIES.map { |p, d| p.find(d) }
  end
end
