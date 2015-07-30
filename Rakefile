require "bundler/gem_tasks"

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task :test => :spec
task :default => :spec

require 'resque'
require 'resque/tasks'
require 'taskinator'

Taskinator.configure do |config|
  config.logger.level = 0  # DEBUG
  config.instrumenter = Taskinator::ConsoleInstrumenter.new
end
