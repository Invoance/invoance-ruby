# frozen_string_literal: true

require_relative "lib/invoance/version"

Gem::Specification.new do |spec|
  spec.name = "invoance"
  spec.version = Invoance::VERSION
  spec.authors = ["Invoance, Inc."]
  spec.email = ["sdk@invoance.com"]

  spec.summary = "Official Ruby SDK for the Invoance compliance API"
  spec.description = "Official Ruby SDK for the Invoance compliance API. " \
                     "Cryptographic proof infrastructure: sign and verify events, documents, " \
                     "AI attestations, traces, and audit logs. Zero runtime dependencies."
  spec.homepage = "https://invoance.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Invoance/invoance-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/Invoance/invoance-ruby/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb"] + %w[README.md LICENSE CHANGELOG.md]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "webmock", "~> 3.19"
end
