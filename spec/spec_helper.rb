require 'bundler/setup'
Bundler.setup

require 'simplecov'
require 'coveralls'
require 'pry'
require 'active_support/notifications'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
])

SimpleCov.start do
  add_filter 'spec'
end

require 'fakeredis/rspec'

require 'delayed_job'

require 'sidekiq'
require 'rspec-sidekiq'
Sidekiq::Testing.fake!

require 'resque'
require 'resque_spec'
ResqueSpec.disable_ext = false

require 'taskinator'

Taskinator.configure do |config|

  # use active support for instrumentation
  config.instrumenter = ActiveSupport::Notifications

  # use a "null stream" for logging
  config.logger = Logger.new(File::NULL)

end

# require supporting files with custom matchers and macros, etc
Dir[File.expand_path("../support/**/*.rb", __FILE__)].each {|f| require f }

RSpec.configure do |config|

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.mock_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random
  config.fail_fast = (ENV["FAIL_FAST"] == 1)

  config.before(:each) do
    Taskinator.queue_adapter = :test_queue
  end

  config.before(:each, :redis => true) do
    Taskinator.redis = { :namespace => "taskinator:test:#{SecureRandom.uuid}" }
  end

  config.before(:each, :sidekiq => true) do
    Sidekiq::Worker.clear_all
  end

  config.before(:each, :delayed_job => true) do
    Delayed::Job.clear_all
  end

end

# require examples, must happen after configure
Dir[File.expand_path("../examples/**/*.rb", __FILE__)].each {|f| require f }

def recursively_enumerate_tasks(tasks, &block)
  tasks.each do |task|
    if task.is_a?(Taskinator::Task::SubProcess)
      recursively_enumerate_tasks(task.sub_process.tasks, &block)
    else
      yield task
    end
  end
end
