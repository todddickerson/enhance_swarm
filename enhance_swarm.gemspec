# frozen_string_literal: true

require_relative 'lib/enhance_swarm/version'

Gem::Specification.new do |spec|
  spec.name = 'enhance_swarm'
  spec.version = EnhanceSwarm::VERSION
  spec.authors = ['Todd Dickerson']
  spec.email = ['todd@spontent.com']

  spec.summary = 'Comprehensive Claude Swarm orchestration framework with best practices'
  spec.description = 'EnhanceSwarm extracts and automates Claude Swarm multi-agent orchestration patterns, including the ENHANCE protocol, task management, MCP integrations, and token optimization strategies. Built from production experience with Rails 8 applications.'
  spec.homepage = 'https://github.com/todddickerson/enhance_swarm'
  spec.required_ruby_version = '>= 3.0.0'
  spec.license = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/todddickerson/enhance_swarm'
  spec.metadata['changelog_uri'] = 'https://github.com/todddickerson/enhance_swarm/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Core dependencies
  spec.add_dependency 'colorize', '~> 1.1'
  spec.add_dependency 'listen', '~> 3.8'
  spec.add_dependency 'parallel', '~> 1.24'
  spec.add_dependency 'psych', '~> 5.1'
  spec.add_dependency 'thor', '~> 1.3'
  spec.add_dependency 'webrick', '~> 1.8'
  spec.add_dependency 'tty-table', '~> 0.12'
  spec.add_dependency 'tty-prompt', '~> 0.23'
  spec.add_dependency 'fileutils', '~> 1.7'
  
  # Task management - note: install separately with: gem install swarm_tasks
  # spec.add_dependency 'swarm_tasks' # Uncomment when gem is published

  # Development dependencies
  spec.add_development_dependency 'pry', '~> 0.14'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.60'
end
