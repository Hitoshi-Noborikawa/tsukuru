# frozen_string_literal: true

require_relative "lib/tsukuru/version"

Gem::Specification.new do |spec|
  spec.name = "tsukuru"
  spec.version = Tsukuru::VERSION
  spec.authors = ["Hitoshi-Noborikawa", "Nakatani Ichiro"]
  spec.email = ["nobo@sonicgarden.jp", "ichiroc@sonicgarden.jp"]

  spec.summary = "tsukuru is a tool that generates code using AI."
  spec.description = "tsukuru is a tool that generates code using AI."
  spec.homepage = "https://github.com/Hitoshi-Noborikawa/tsukuru"
  spec.required_ruby_version = ">= 3.1.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Hitoshi-Noborikawa/tsukuru"
  spec.metadata["changelog_uri"] = "https://github.com/Hitoshi-Noborikawa/tsukuru"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "tty-reader", ">= 0.9.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
