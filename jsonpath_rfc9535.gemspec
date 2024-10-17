# frozen_string_literal: true

require_relative "lib/jsonpath_rfc9535/version"

Gem::Specification.new do |spec|
  spec.name = "jsonpath_rfc9535"
  spec.version = JSONPathRFC9535::VERSION
  spec.authors = ["James Prior"]
  spec.email = ["jamesgr.prior@gmail.com"]

  spec.summary = "JSONPath: Query Expressions for JSON in Ruby"
  spec.description = "JSONPath following RFC 9535"
  spec.homepage = "https://github.com/jg-rp/ruby-jsonpath-rfc9535"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jg-rp/ruby-jsonpath-rfc9535"
  spec.metadata["changelog_uri"] = "https://github.com/jg-rp/ruby-jsonpath-rfc9535/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
