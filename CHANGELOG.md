## [1.0.0] - unreleased

- Changed the JSONPath tokenizer and parser. The new parser is faster and more JIT friendly.
- Changed our module and class layout to better separate JSONPath, JSON Pointer and JSON Patch, and to remove "stuttering". For example, previously we had `JSONP3::JSONPathEnvironment` and `JSONP3::JSONPathNode`. Now we have `JSONP3::Path::Environment` and `JSONP3::Path:Node`. This ASCII tree view show our new module and class hierarchy.
    
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
        └── def self.apply
    ```

    Note that top-level convenience methods - like `JSONP3.find` and `JSONP3.compile` - are unchanged. Most dependent projects should only need to change error class names.

- Renamed `JSONP3::JSONPath` to `JSONP3::Path::Query`.
- Renamed `JSONP3::RecursiveDescentSegment` to `JSONP3::Path::DescendantSegment` to better match the spec.
- Dropped support for Ruby 3.1 and 3.2, they are end of life.

## [0.4.1] - 2025-03-18

- Fixed `JSONPathSyntaxError` claiming "unbalanced parentheses" when the query has balanced brackets.

## [0.4.0] - 2025-02-10

- Added `JSONP3.find_enum`, `JSONP3::JSONPathEnvironment.find_enum` and `JSONP3::JSONPath.find_enum`. `find_enum` is like `find`, but returns an Enumerable (usually an Enumerator) of `JSONPathNode` instances instead of a `JSONPathNodeList`. `find_enum` can be more efficient for some combinations of query and data, especially for large data and recursive queries.
- Added `JSONP3.match`, `JSONP3.match?`, `JSONP3.first` and equivalent methods for `JSONPathEnvironment` and `JSONPath`.

## [0.3.2] - 2025-01-29

- Fix normalized string representations of node locations as returned by `JSONPathNode.path`.
- Fix canonical string representations of instances of `JSONPath`, as returned by `to_s`.
- Fixed filter queries with multiple bracketed segments. Previously we were failing to tokenize queries like `$[?@[0][0]]`. See [#15](https://github.com/jg-rp/ruby-json-p3/issues/15).

## [0.3.1] - 2024-12-05

- Fix JSON Patch `move` and `copy` operations when using the special JSON Pointer token `-`.

## [0.3.0] - 2024-11-25

- Implement JSON Pointer and Relative JSON Pointer
- Implement JSON Patch

## [0.2.1] - 2024-10-24

- Rename project and gem

## [0.2.0] - 2024-10-24

- Initial release
