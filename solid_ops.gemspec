# frozen_string_literal: true

require_relative "lib/solid_ops/version"

Gem::Specification.new do |spec|
  spec.name = "solid_ops"
  spec.version = SolidOps::VERSION
  spec.authors = ["samuel-murphy"]
  spec.email = ["samuelmurphy15@gmail.com"]

  spec.summary = "Rails-native observability and control plane for the Solid Trifecta"
  spec.description = "SolidOps provides a real-time dashboard and management UI for Solid Queue, " \
                     "Solid Cache, and Solid Cable — built as a mountable Rails engine with zero JavaScript dependencies."
  spec.homepage = "https://github.com/h0m1c1de/solid_ops"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/h0m1c1de/solid_ops"
  spec.metadata["changelog_uri"] = "https://github.com/h0m1c1de/solid_ops/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml]) ||
        f.start_with?(*%w[node_modules/ package.json package-lock.json tailwind.config.js]) ||
        f == "app/assets/stylesheets/solid_ops/application.tailwind.css"
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "rails", ">= 7.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
