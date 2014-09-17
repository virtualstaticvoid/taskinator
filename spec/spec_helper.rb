require 'bundler/setup'
Bundler.setup

require 'simplecov'
require 'coveralls'
require 'pry'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]

SimpleCov.start do
  add_filter 'spec'
end

require 'delayed_job'

require 'sidekiq'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require 'resque'
require 'resque_spec'
ResqueSpec.disable_ext = false

require 'taskinator'

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
    Taskinator.redis = { :namespace => 'taskinator:test' }
    Taskinator.redis do |conn|
      conn.flushdb
    end
  end

end

# require examples, must happen after configure
Dir[File.expand_path("../examples/**/*.rb", __FILE__)].each {|f| require f }
