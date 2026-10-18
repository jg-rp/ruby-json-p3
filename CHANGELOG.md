## [1.0.1] - 2026-10-18

- Fixed the JSON Patch `move` operation overwriting the item at its target array index instead of inserting before it, which corrupted arrays when reordering their items. [RFC 6902 section 4.4](https://datatracker.ietf.org/doc/html/rfc6902#section-4.4) defines `move` as a `remove` followed by an `add`, and [section 4.1](https://datatracker.ietf.org/doc/html/rfc6902#section-4.1) says that when an `add` targets an array index "a new value is inserted into the array at the specified index".
- Fixed the JSON Patch `add` operation rejecting an array index equal to the length of the array. [RFC 6902 section 4.1](https://datatracker.ietf.org/doc/html/rfc6902#section-4.1) only requires that the specified index "MUST NOT be greater than the number of elements in the array", so an index equal to the length is valid and appends to the array.
- Fixed the JSON Patch `move` and `copy` operations padding an array with `nil` when their target index was past the end of the array. Both are defined in terms of `add` (RFC 6902 [section 4.4](https://datatracker.ietf.org/doc/html/rfc6902#section-4.4) and [section 4.5](https://datatracker.ietf.org/doc/html/rfc6902#section-4.5)), whose index "MUST NOT be greater than the number of elements in the array" ([section 4.1](https://datatracker.ietf.org/doc/html/rfc6902#section-4.1)). Under [section 5](https://datatracker.ietf.org/doc/html/rfc6902#section-5), violating a normative requirement means the patch "SHALL NOT be deemed successful", so they now raise a `JSONP3::Patch::Error`, as `add` does.
- Fixed the JSON Patch `move` and `copy` operations replacing the whole document with the moved or copied value when the parent of the target does not exist. [RFC 6902 section 4.1](https://datatracker.ietf.org/doc/html/rfc6902#section-4.1) says the object or array being added to "does need to exist, and it remains an error for that not to be the case", and `move` and `copy` inherit that from `add` ([section 4.4](https://datatracker.ietf.org/doc/html/rfc6902#section-4.4) and [section 4.5](https://datatracker.ietf.org/doc/html/rfc6902#section-4.5)). They now raise a `JSONP3::Patch::Error`.
- Fixed the JSON Patch `move` operation silently discarding the moved value when the parent of the target is neither an array nor an object. [RFC 6902 section 4.1](https://datatracker.ietf.org/doc/html/rfc6902#section-4.1) says the target location "MUST reference one of" the document root, a member of an existing object or an element of an existing array, and [section 5](https://datatracker.ietf.org/doc/html/rfc6902#section-5) requires an operation that cannot succeed to fail the patch. It now raises a `JSONP3::Patch::Error`, as `add` and `copy` already did.
- Fixed the JSON Patch `copy` operation not copying the value when appending it to an array with `-`, so the copy and its source shared nested arrays and objects. [RFC 6902 section 4.5](https://datatracker.ietf.org/doc/html/rfc6902#section-4.5) defines `copy` as an `add` of the value at `from`, which leaves the document with two independent values. With the shared objects, a later operation on one changed the other, and copying an array to its own end made the array contain itself.
- Fixed JSON Patch operations targeting an object member whose name is a non-negative integer, like `/foo/1`. `add`, `copy` and `move` wrote the value under an integer key instead of the member name, duplicating the member when it already existed, `replace` added an integer key alongside the existing member, `remove` did nothing, and `move` left its source member in place. Under [RFC 6901 section 4](https://datatracker.ietf.org/doc/html/rfc6901#section-4), when a reference token is applied to an object, "the new referenced value is the object member with the name identified by the reference token". A token is only read as an array index when it is applied to an array. [RFC 8259 section 4](https://datatracker.ietf.org/doc/html/rfc8259#section-4) says "A name is a string" and "The names within an object SHOULD be unique", so a second key for the same name produced JSON with duplicate member names.
- Fixed trailing comma detection in JSONPath bracketed segments. Previously we failed to consume whitespace after a comma and before checking for `]`.
- Fixed JSONPath `\u` escape sequence rejection of code points less than or equal to 0x1F. The spec requires us to reject literals of 0x1F or lower, not escape sequences.
- Fixed the JSONPath shorthand name selector to accept the full range of allow Unicode code points.
- Fixed the JSONPath slice selector when a start index equal to the target array's length and default end and step values would result in selecting the last value in the array.

## [1.0.0] - 2026-04-21

This major release includes breaking changes. No new features have been added.

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
      └── def !self.apply
  ```

  Note that top-level convenience methods - like `JSONP3.find` and `JSONP3.compile` - are unchanged. Most dependent projects should only need to change error class names.

- Renamed `JSONP3::JSONPath` to `JSONP3::Path::Query`.
- Renamed `JSONP3::RecursiveDescentSegment` to `JSONP3::Path::DescendantSegment` to better match the spec.
- Renamed `JSONP3.apply` to `JSONP3.apply!`, `JSONP3::Patch#apply` to `JSONP3::Patch#apply!` and `JSONP3::Patch::Op#apply` to `JSONP3::Patch::Op#apply!`. There is no "safe", non mutating version of `apply!`.
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
