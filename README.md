<h1 align="center">JSONPath, JSON Patch and JSON Pointer for Ruby</h1>

<p align="center">
We follow <a href="https://datatracker.ietf.org/doc/html/rfc9535">RFC 9535</a> strictly and test against the <a href="https://github.com/jsonpath-standard/jsonpath-compliance-test-suite">JSONPath Compliance Test Suite</a>.
</p>

<p align="center">
  <a href="https://github.com/jg-rp/ruby-json-p3/blob/main/LICENSE.txt">
    <img src="https://img.shields.io/pypi/l/jsonpath-rfc9535.svg?style=flat-square" alt="License">
  </a>
  <a href="https://github.com/jg-rp/ruby-json-p3/actions">
    <img src="https://img.shields.io/github/actions/workflow/status/jg-rp/ruby-json-p3/main.yml?branch=main&label=tests&style=flat-square" alt="Tests">
  </a>
  <br>
  <a href="https://rubygems.org/gems/json_p3">
    <img alt="Gem Version" src="https://img.shields.io/gem/v/json_p3?style=flat-square">
  </a>
  <a href="https://github.com/jg-rp/ruby-json-p3">
    <img alt="Static Badge" src="https://img.shields.io/badge/Ruby-3.3%20%7C%203.4%20%7C%204.0-CC342D?style=flat-square">
  </a>
</p>

---

**Table of Contents**

- [Install](#install)
- [Example](#example)
- [Links](#links)
- [Related projects](#related-projects)
- [Quick start](#quick-start)
- [Class and module layout](#module-layout)
- [Contributing](#contributing)

## Install

Add `'json_p3'` to your Gemfile:

```
gem 'json_p3', '~> 1.0.0'
```

Or

```
gem install json_p3
```

Or

```
bundle add json_p3
```

### Checksum

JSON P3 is cryptographically signed. To be sure the gem you install hasn't been tampered with, add my public key (if you haven't already) as a trusted certificate:

```
gem cert --add <(curl -Ls https://raw.githubusercontent.com/jg-rp/ruby-json-p3/refs/heads/main/certs/jgrp.pem)
```

Followed by:

```
gem install json_p3 -P MediumSecurity
```

JSON P3 has no runtime dependencies, so `-P HighSecurity` is OK too. See https://guides.rubygems.org/security/ for more information.

## Example

```ruby
require "json_p3"
require "json"

data = JSON.parse <<~JSON
  {
    "users": [
      { "name": "Sue", "score": 100 },
      { "name": "Sally", "score": 84, "admin": false },
      { "name": "John", "score": 86, "admin": true },
      { "name": "Jane", "score": 55 }
    ],
    "moderator": "John"
  }
JSON

JSONP3.find("$.users[?@.score > 85]", data).each do |node|
  puts node.value
end

# {"name"=>"Sue", "score"=>100}
# {"name"=>"John", "score"=>86, "admin"=>true}
```

Or, reading JSON data from a file:

```ruby
require "json_p3"
require "json"

data = JSON.load_file("/path/to/some.json")

JSONP3.find("$.some.query", data).each do |node|
  puts node.value
end
```

You could read data from a YAML formatted file too, or any data format that can be loaded into hashes and arrays.

```ruby
require "json_p3"
require "yaml"

data = YAML.load_file("/tmp/some.yaml")

JSONP3.find("$.users[?@.score > 85]", data).each do |node|
  puts node.value
end
```

## Links

- Change log: https://github.com/jg-rp/ruby-json-p3/blob/main/CHANGELOG.md
- RubyGems: https://rubygems.org/gems/json_p3
- Source code: https://github.com/jg-rp/ruby-json-p3
- Issue tracker: https://github.com/jg-rp/ruby-json-p3/issues

## Related projects

- [Python JSONPath RFC 9535](https://github.com/jg-rp/python-jsonpath-rfc9535) - A Python implementation of JSONPath that follows RFC 9535 strictly.
- [Python JSONPath](https://github.com/jg-rp/python-jsonpath) - Another Python package implementing JSONPath, but with additional features and customization options.
- [JSON P3](https://github.com/jg-rp/json-p3) - RFC 9535 implemented in TypeScript.

## Quick start

### find

`find: (String query, top value) -> Array[JSONP3::Path::Node]`

Apply query expression _query_ to JSON-like data _value_. An array of `Node` instances is returned, one node for each value matched by _query_.

For each `Node`:

- `#value` is the JSON-like value associated with the node.
- `#location` is an array of object keys and array indices used to reach the node's value in the target document.
- `#path` returns the normalized path to the node in the target JSON document. Normalized paths are computed from `#location` and are not cached between calls.

```ruby
require "json_p3"
require "json"

data = JSON.parse <<~JSON
  {
    "users": [
      { "name": "Sue", "score": 100 },
      { "name": "Sally", "score": 84, "admin": false },
      { "name": "John", "score": 86, "admin": true },
      { "name": "Jane", "score": 55 }
    ],
    "moderator": "John"
  }
JSON

JSONP3.find("$.users[?@.score > 85]", data).each do |node|
  puts "#{node.value} at #{node.path}"
end

# {"name"=>"Sue", "score"=>100} at $['users'][0]
# {"name"=>"John", "score"=>86, "admin"=>true} at $['users'][2]
```

The returned array will be empty if there were no matches.

### find_enum

`find_enum: (String query, top value) -> Enumerable[JSONP3::Path::Node]`

`JSONP3.find_enum` is an alternative to `find` which returns an enumerable (usually an enumerator) of `Node` instances instead of an array. Depending on the query and the data the query is applied to, `find_enum` can be more efficient than `find`, especially for large data and queries using descendant segments.

```ruby
# ... continued from above

JSONP3.find_enum("$.users[?@.score > 85]", data).each do |node|
  puts "#{node.value} at #{node.path}"
end

# {"name"=>"Sue", "score"=>100} at $['users'][0]
# {"name"=>"John", "score"=>86, "admin"=>true} at $['users'][2]
```

### compile

`compile: (String query) -> JSONP3::Path::Query`

Prepare a query for repeated application to different JSON-like data. An instance of `Query` has `#find(data)`, which behaves similarly to the module-level `find(query, data)` method.

```ruby
require "json_p3"
require "json"

data = JSON.parse <<~JSON
  {
    "users": [
      { "name": "Sue", "score": 100 },
      { "name": "Sally", "score": 84, "admin": false },
      { "name": "John", "score": 86, "admin": true },
      { "name": "Jane", "score": 55 }
    ],
    "moderator": "John"
  }
JSON

path = JSONP3.compile("$.users[?@.score > 85]")

path.find(data).each do |node|
  puts "#{node.value} at #{node.path}"
end

# {"name"=>"Sue", "score"=>100} at $['users'][0]
# {"name"=>"John", "score"=>86, "admin"=>true} at $['users'][2]
```

### match / first

`match: (String query, top value) -> (JSONP3::Path::Node | nil)`

`JSONP3.match` (alias `first`) returns a node for the first available match when applying _query_ to _value_, or `nil` if there were no matches.

### match?

`match?: (String query, top value) -> bool`

`JSONP3.match?` returns `true` if there was at least one match from applying _query_ to _value_, or `false` otherwise.

### JSONP3::Path::Environment

The `find`, `find_enum` and `compile` methods described above are convenience methods equivalent to:

```
JSONP3::Path::DEFAULT_ENVIRONMENT.find(query, data)
```

```
JSONP3::Path::DEFAULT_ENVIRONMENT.find_enum(query, data)
```

and

```
JSONP3::Path::DEFAULT_ENVIRONMENT.compile(query)
```

You can create your own environment like this:

```ruby
require "json_p3"

jsonpath = JSONP3::Path::Environment.new
nodes = jsonpath.find("$.*", { "a" => "b", "c" => "d" })
pp nodes.map(&:value) # ["b", "d"]
```

To configure an environment with custom filter functions or non-standard selectors, inherit from `JSONP3::Path::Environment` and override some of its constants or the `#setup_function_extensions` method.

```ruby
class MyJSONPathEnvironment < JSONP3::Path::Environment
  # The maximum integer allowed when selecting array items by index.
  MAX_INT_INDEX = (2**53) - 1

  # The minimum integer allowed when selecting array items by index.
  MIN_INT_INDEX = -(2**53) + 1

  # The maximum number of arrays and hashes the recursive descent segment will
  # traverse before raising a {JSONPathRecursionError}.
  MAX_RECURSION_DEPTH = 100

  # One of the available implementations of the _name selector_.
  #
  # - {NameSelector} (the default) will select values from hashes using string keys.
  # - {SymbolNameSelector} will select values from hashes using string or symbol keys.
  #
  # Implement your own name selector by inheriting from {NameSelector} and overriding
  # `#resolve`.
  NAME_SELECTOR = NameSelector

  # An implementation of the _index selector_. The default implementation will
  # select values from arrays only. Implement your own by inheriting from
  # {IndexSelector} and overriding `#resolve`.
  INDEX_SELECTOR = IndexSelector

  # Override this function to configure JSONPath function extensions.
  # By default, only the standard functions described in RFC 9535 are enabled.
  def setup_function_extensions
    @function_extensions["length"] = JSONP3::Path::Length.new
    @function_extensions["count"] = JSONP3::Path::Count.new
    @function_extensions["value"] = JSONP3::Path::Value.new
    @function_extensions["match"] = JSONP3::Path::Match.new
    @function_extensions["search"] = JSONP3::Path::Search.new
  end
```

### Errors

`JSONP3::Error` is the base class for all exceptions raised from this Gem.

```
StandardError
└── JSONP3::Error
    ├── JSONP3::Path::Error
    │   └── SyntaxError, TypeError, NameError, RecursionError
    ├── JSONP3::Pointer::Error
    │   └── IndexError, SyntaxError, TypeError
    └── JSONP3::Patch::Error
        └── TestFailure
```

`JSONP3::Path::Error` inherits from `JSONP3::Error` and implements `#detailed_message`. With recent versions of Ruby you should get useful error messages.

```
JSONP3::Path::SyntaxError: unexpected trailing whitespace
  -> '$.foo ' 1:5
  |
1 | $.foo
  |      ^ unexpected trailing whitespace
```

### resolve

`resolve: (String pointer, top value, ?default: top) -> Object`

Resolve a JSON Pointer (RFC 6901) against some data using `JSONP3.resolve`.

```ruby
require "json_p3"
require "json"

data = JSON.parse <<~JSON
  {
    "users": [
      { "name": "Sue", "score": 100 },
      { "name": "Sally", "score": 84, "admin": false },
      { "name": "John", "score": 86, "admin": true },
      { "name": "Jane", "score": 55 }
    ],
    "moderator": "John"
  }
JSON

puts JSONP3.resolve("/users/1", data)
# {"name"=>"Sally", "score"=>84, "admin"=>false}
```

If a pointer can not be resolved, `JSONP3::Pointer::UNDEFINED` is returned instead. You can use your own default value using the `default:` keyword argument.

```ruby
# continued from above

pp JSONP3.resolve("/no/such/thing", data, default: nil) # nil
```

### apply!

`apply!: (Array[Patch::Op | Hash[String, untyped]] ops, top value) -> Object`

Apply a JSON Patch ([RFC 6902](https://datatracker.ietf.org/doc/html/rfc6902)) with `JSONP3.apply!`. **Data is modified in place**.

```ruby
require "json"
require "json_p3"

ops = <<~JSON
  [
    { "op": "add", "path": "/some/foo", "value": { "foo": {} } },
    { "op": "add", "path": "/some/foo", "value": { "bar": [] } },
    { "op": "copy", "from": "/some/other", "path": "/some/foo/else" },
    { "op": "add", "path": "/some/foo/bar/-", "value": 1 }
  ]
JSON

data = { "some" => { "other" => "thing" } }
JSONP3.apply!(JSON.parse(ops), data)
pp data
# {"some"=>{"other"=>"thing", "foo"=>{"bar"=>[1], "else"=>"thing"}}}
```

`JSONP3.apply!(ops, value)` is a convenience method equivalent to `JSONP3::Patch.new(ops).apply!(value)`. Use the `Patch` constructor when you need to apply the same patch to different data.

As well as passing an array of hashes following RFC 6902 as ops to `Patch`, we offer a builder API to construct JSON Patch documents programmatically.

```ruby
require "json_p3"

data = { "some" => { "other" => "thing" } }

patch = JSONP3::Patch.new
                     .add("/some/foo", { "foo" => [] })
                     .add("/some/foo", { "bar" => [] })
                     .copy("/some/other", "/some/foo/else")
                     .copy("/some/foo/else", "/some/foo/bar/-")

patch.apply!(data)
pp data
# {"some"=>{"other"=>"thing", "foo"=>{"bar"=>["thing"], "else"=>"thing"}}}
```

## Module layout

```
module JSONP3
├── class Error < StandardError
│
├── module Path                              # JSONPath (RFC 9535)
│   ├── class Environment                    
│   ├── class Query    
│   ├── class Node
│   ├── class NodeList
│   ├── class Error < JSONP3::Error
│   │    ├── class SyntaxError
│   │    ├── class TypeError
│   │    ├── class NameError
│   │    └── class RecursionError
│   ├── def self.find
│   ├── def self.find_enum
│   ├── def self.compile
│   ├── def self.match
│   ├── def self.match?
│   └── def self.first
│
├── class Pointer                            # JSON Pointer (RFC 6901)
│   ├── class Error < JSONP3::Error
│   │   ├── class IndexError
│   │   ├── class SyntaxError
│   │   └── class TypeError
│   └── def self.resolve
│
└── class Patch                              # JSON Patch (RFC 6902)
    ├── class OpAdd                          
    ├── class OpCopy                          
    ├── class OpMove                          
    ├── class OpRemove                       
    ├── class OpReplace                       
    ├── class OpTest                       
    ├── class Error < JSONP3::Error
    │   └── class TestFailure
    └── def self.!apply
```

## Contributing

Your contributions and questions are always welcome. Feel free to ask questions, report bugs or request features on the [issue tracker](https://github.com/jg-rp/ruby-json-p3/issues) or on [Github Discussions](https://github.com/jg-rp/ruby-json-p3/discussions). Pull requests are welcome too.

### Development

The [JSONPath Compliance Test Suite](https://github.com/jsonpath-standard/jsonpath-compliance-test-suite) is included as a git [submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules). Clone the JSON P3 git repository and initialize the CTS submodule.

```shell
$ git clone git@github.com:jg-rp/ruby-json-p3.git
$ cd ruby-json-p3
$ git submodule update --init
```

We use [Bundler](https://bundler.io/) and [Rake](https://ruby.github.io/rake/). Install development dependencies with:

```
bundle install
```

Run tests with:

```
bundle exec rake test
```

Lint with:

```
bundle exec rubocop
```

And type check with:

```
bundle exec steep
```

Run one of the benchmarks with:

```
bundle exec ruby performance/benchmark_ips.rb
```

### Profiling

#### CPU profile

Dump profile data with `bundle exec ruby performance/profile.rb`, then generate an HTML flame graph with:

```
bundle exec stackprof --d3-flamegraph .stackprof-cpu-just-compile.dump > flamegraph-cpu-just-compile.html
```

#### Memory profile

Print memory usage to the terminal.

```
bundle exec ruby performance/memory_profile.rb
```

### Notes to self

#### Build

`bundle exec rake release` and `bundle exec rake build` will look for `gem-private_key.pem` and `gem-public_cert.pem` in `~/.gem`.

#### TruffleRuby

On macOS Sonoma using MacPorts and `rbenv`, `LIBYAML_PREFIX=/opt/local/lib` is needed to install TruffleRuby and when executing any `bundle` command.
