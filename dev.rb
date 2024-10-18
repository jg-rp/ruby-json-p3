# frozen_string_literal: true

require "json"
require "jsonpath_rfc9535"

query = "$[?@]"

document = <<~JSON
  {
        "a": 1,
        "b": null
      }
JSON

data = JSON.parse(document)

pp JSONPathRFC9535.tokenize(query)

path = JSONPathRFC9535::DefaultEnvironment.compile(query)
puts path

nodes = path.find(data)
puts "NODES: "
puts(nodes.map(&:value))
puts "END"
