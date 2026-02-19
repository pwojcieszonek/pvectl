# frozen_string_literal: true

require_relative "lib/pvectl/version"

Gem::Specification.new do |spec|
  spec.name = "pvectl"
  spec.version = Pvectl::VERSION
  spec.authors = ["Piotr Wojcieszonek"]
  spec.email = ["piotr@wojcieszonek.pl"]

  spec.summary = "A command-line tool for managing Proxmox clusters with a kubectl-like syntax."
  spec.description = "Pvectl is a CLI tool designed to aid in the management of Proxmox clusters, leveraging a syntax and approach similar to kubectl for ease of use and familiarity."
  spec.homepage = "https://github.com/pwojcieszonek/pvectl"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/pwojcieszonek/pvectl"
  spec.metadata["changelog_uri"] = "https://github.com/pwojcieszonek/pvectl/CHANGELOG.md"

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
  spec.add_dependency "gli", "~> 2.22"
  spec.add_dependency "proxmox-api", "~> 1.1"
  spec.add_dependency "tty-table", "~> 0.12"
  spec.add_dependency "pastel", "~> 0.8"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end