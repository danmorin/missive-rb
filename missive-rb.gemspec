# frozen_string_literal: true

require_relative "lib/missive/version"

Gem::Specification.new do |spec|
  spec.name = "missive-rb"
  spec.version = Missive::VERSION
  spec.authors = ["Dan Morin"]
  spec.email = ["dan.morin@gmail.com"]

  spec.summary = "Ruby client for the Missive API"
  spec.description = "A Ruby gem that provides a simple interface to interact with the Missive API for team email management"
  spec.homepage = "https://github.com/danmorin/missive-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/danmorin/missive-rb"
  spec.metadata["changelog_uri"] = "https://github.com/danmorin/missive-rb/blob/main/CHANGELOG.md"

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

  # Dependencies
  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "concurrent-ruby", "~> 1.2"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "mutex_m", "~> 0.2"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "true"
end
