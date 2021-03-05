require 'json'
require 'yaml'
require 'securerandom'
require 'benchmark'
require 'delegate'

require 'taskinator/version'

require 'taskinator/log_stats'

require 'taskinator/complete_on'
require 'taskinator/redis_connection'
require 'taskinator/logger'

require 'taskinator/definition'

require 'taskinator/workflow'

require 'taskinator/visitor'
require 'taskinator/persistence'
require 'taskinator/instrumentation'
require 'taskinator/xml_visitor'

require 'taskinator/task'
require 'taskinator/tasks'
require 'taskinator/process'

require 'taskinator/task_worker'
require 'taskinator/process_worker'
require 'taskinator/create_process_worker'

require 'taskinator/executor'
require 'taskinator/queues'

require 'taskinator/api'

module Taskinator

  NAME = "Taskinator"
  LICENSE = 'See LICENSE.txt for licensing details.'

  DEFAULTS = {
    # none for now...
  }

  class << self
    def options
      @options ||= DEFAULTS.dup
    end
    def options=(opts)
      @options = opts
    end

    def generate_uuid
      SecureRandom.uuid
    end

    ##
    # Configuration for Taskinator client, use like:
    #
    #   Taskinator.configure do |config|
    #     config.redis = { :namespace => 'myapp', :pool_size => 1, :url => 'redis://myhost:8877/0' }
    #     config.queue_config = { :process_queue => 'processes', :task_queue => 'tasks' }
    #   end
    #
    def configure
      yield self if block_given?
    end

    def redis(&block)
      raise ArgumentError, "requires a block" unless block_given?
      redis_pool.with(&block)
    end

    def redis_pool
      @redis ||= Taskinator::RedisConnection.create
    end

    def redis=(hash)
      @redis = Taskinator::RedisConnection.create(hash)
    end

    def logger
      Taskinator::Logging.logger
    end

    def logger=(log)
      Taskinator::Logging.logger = log
    end

    def statsd_client
      Taskinator::LogStats.client
    end

    def statsd_client=(client)
      Taskinator::LogStats.client = client
    end

    # the queue adapter to use
    # supported adapters include
    # :delayed_job, :redis and :sidekiq
    # NOTE: ensure that the respective gem is included
    attr_reader :queue_adapter

    def queue_adapter=(adapter)
      @queue_adapter = adapter
      @queue = nil
    end

    # configuration, usually a hash, which will be passed
    # to the configured queue adapter
    attr_reader :queue_config

    def queue_config=(config)
      @queue_config = config
      @queue = nil
    end

    def queue
      @queue ||= begin
        adapter = self.queue_adapter || :resque
        config = queue_config || {}
        Taskinator::Queues.create_adapter(adapter, config)
      end
    end

    # set the instrumenter to use.
    # can be ActiveSupport::Notifications
    def instrumenter
      @instrumenter ||= NoOpInstrumenter.new
    end
    def instrumenter=(value)
      @instrumenter = value
    end

  end

  class NoOpInstrumenter
    # :nocov:
    def instrument(event, payload={})
      yield(payload) if block_given?
    end
  end

  class ConsoleInstrumenter
    # :nocov:
    def instrument(event, payload={})
      puts [event.inspect, payload.to_yaml]
      yield(payload) if block_given?
    end
  end

end
