module Taskinator
  module Queues

    DefaultConfig = {
      :definition_queue => :default,
      :process_queue => :default,
      :task_queue => :default
    }.freeze

    def self.create_adapter(adapter, config={})
      begin
        LoggedAdapter.new(send("create_#{adapter}_adapter", config))
      rescue NoMethodError
        raise "The queue adapter `#{adapter}` is not yet supported or it's runtime isn't loaded."
      end
    end

    class LoggedAdapter < Delegator

      attr_reader :adapter

      def initialize(adapter)
        Taskinator.logger.info("Initialized '#{adapter.class.name}' queue adapter")
        @adapter = adapter
      end

      def __getobj__
        adapter
      end

      def enqueue_create_process(definition, uuid, args)
        Taskinator.logger.info("Enqueuing process creation for #{definition}")
        adapter.enqueue_create_process(definition, uuid, args)
      end

      def enqueue_task(task)
        Taskinator.logger.info("Enqueuing task #{task}")
        adapter.enqueue_task(task)
      end

    end

  end
end

require 'taskinator/queues/active_job' if defined?(ApplicationJob)
require 'taskinator/queues/delayed_job' if defined?(Delayed)
require 'taskinator/queues/resque' if defined?(Resque)
require 'taskinator/queues/sidekiq' if defined?(Sidekiq)
