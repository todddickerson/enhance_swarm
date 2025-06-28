# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc "Install the gem locally"
task :install_local do
  sh "bundle exec rake build"
  sh "gem install pkg/enhance_swarm-*.gem"
end

desc "Run a quick test of the CLI"
task :test_cli do
  sh "bundle exec exe/enhance-swarm --help"
  sh "bundle exec exe/enhance-swarm version"
  sh "bundle exec exe/enhance-swarm doctor"
end

desc "Generate documentation"
task :docs do
  sh "yard doc"
end