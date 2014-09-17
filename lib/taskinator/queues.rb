module Taskinator
  module Queues

    def self.create_adapter(adapter, config={})
      begin
        LoggedAdapter.new(send("create_#{adapter}_adapter", config))
      rescue NoMethodError
        raise "The queue adapter `#{adapter}` is not yet supported or it's runtime isn't loaded."
      end
    end

    class LoggedAdapter

      attr_reader :adapter

      def initialize(adapter)
        Taskinator.logger.info("Initialized '#{adapter.class.name}' queue adapter")
        @adapter = adapter
      end

      def enqueue_process(process)
        Taskinator.logger.info("Enqueuing process #{process}")
        adapter.enqueue_process(process)
      end

      def enqueue_task(task)
        Taskinator.logger.info("Enqueuing task #{task}")
        adapter.enqueue_task(task)
      end

      def enqueue_job(job)
        Taskinator.logger.info("Enqueuing job #{job}")
        adapter.enqueue_job(job)
      end

    end

  end
end

require 'taskinator/queues/delayed_job' if defined?(Delayed)
require 'taskinator/queues/resque' if defined?(Resque)
require 'taskinator/queues/sidekiq' if defined?(Sidekiq)
