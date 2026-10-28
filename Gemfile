# frozen_string_literal: true

source "https://rubygems.org"

gemspec

rails_version = ENV.fetch("RAILS_VERSION", nil)
gem "actionpack", rails_version
gem "activemodel", rails_version
gem "activesupport", rails_version
gem "railties", rails_version

# Rails 7.1 and 8.0 pass `quirks_mode` to JSON.parse, which json 3 removed.
gem "json", "< 3" if ["~> 7.1.0", "~> 8.0.0"].include?(rails_version)

gem "active_interaction"
gem "benchmark"
gem "debug"
gem "memory_profiler"
gem "rack-test"
gem "rake"
gem "rspec"
gem "standard"
gem "store_model"
