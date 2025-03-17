## [0.4.1] - unreleased

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
