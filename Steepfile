# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature "sig"

  check "lib" # Directory name
  #   check "Gemfile"                   # File name
  #   check "app/models/**/*.rb"        # Glob
  # ignore "lib/templates/*.rb"

  # library "pathname"              # Standard libraries
  #   library "minitest"
  #   library "minitest/autorun"

  # configure_code_diagnostics(D::Ruby.default)      # `default` diagnostics setting (applies by default)
  # configure_code_diagnostics(D::Ruby.strict)       # `strict` diagnostics setting
  # configure_code_diagnostics(D::Ruby.lenient)      # `lenient` diagnostics setting
  # configure_code_diagnostics(D::Ruby.silent)       # `silent` diagnostics setting
  # configure_code_diagnostics do |hash|             # You can setup everything yourself
  #   hash[D::Ruby::NoMethod] = :information
  # end
end

target :test do
  signature "sig", "sig-private"

  check "test"
  library "minitest"

  # library "pathname"              # Standard libraries
end
