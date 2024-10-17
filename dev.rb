# frozen_string_literal: true

require "json"
require "jsonpath_rfc9535"

query = "$..*"

document = <<~JSON
  [
        0,
        1
      ]
JSON

data = JSON.parse(document)

path = JSONPathRFC9535::DefaultEnvironment.compile(query)
puts path

nodes = path.find(data)
puts "NODES: "
puts(nodes.map(&:value))
puts "END"
