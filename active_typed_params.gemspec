# frozen_string_literal: true

require File.expand_path("lib/active_typed_params/version", __dir__)

Gem::Specification.new do |s|
  s.name = "active_typed_params"
  s.version = ActiveTypedParams::VERSION
  s.authors = ["Máximo Mussini"]
  s.email = ["maximomussini@gmail.com"]
  s.summary = "Typed strong parameters for Rails controllers, compiled into plain Ruby methods."
  s.description = "Declare the keys and types a controller action accepts. Bad requests are rejected with a 400 that names the parameter, and each declaration is compiled into a single method, several times faster than params.permit."
  s.homepage = "https://github.com/ElMassimo/active_typed_params"
  s.license = "MIT"
  s.metadata = {
    "source_code_uri" => s.homepage,
    "changelog_uri" => "#{s.homepage}/blob/main/CHANGELOG.md",
    "allowed_push_host" => "https://rubygems.org",
    "rubygems_mfa_required" => "true",
  }
  s.extra_rdoc_files = ["README.md"]
  s.files = Dir.glob("lib/**/*.rb") + %w[README.md CHANGELOG.md LICENSE.txt]
  s.require_path = "lib"

  s.required_ruby_version = ">= 3.3.0"

  s.add_dependency "actionpack", ">= 7.1"
  s.add_dependency "activesupport", ">= 7.1"
end
