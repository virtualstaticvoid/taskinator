module Taskinator
  module Queues

    def self.create_test_queue_adapter(config={})
      TestQueueAdapter.new(config)
    end

    def self.create_test_queue_worker_adapter(config={})
      TestQueueWorkerAdapter.new(config)
    end

    #
    # this is a no-op adapter, it tracks enqueued processes and tasks
    #
    class TestQueueAdapter

      def initialize(config={})
        clear
      end

      def enqueue_create_process(definition, uuid, args)
        @processes << [definition, uuid, args]
      end

      def enqueue_task(task)
        @tasks << task
      end

      # helpers

      attr_reader :processes
      attr_reader :tasks

      def clear
        @processes = []
        @tasks = []
      end

      def empty?
        @processes.empty? && @tasks.empty?
      end

    end

    #
    # this is a "synchronous" implementation for use in testing
    #
    class TestQueueWorkerAdapter < TestQueueAdapter

      def enqueue_create_process(definition, uuid, args)
        super
        invoke do
          Taskinator::CreateProcessWorker.new(definition.name, uuid, args).perform
        end
      end

      def enqueue_task(task)
        super
        invoke do
          Taskinator::TaskWorker.new(task.uuid).perform
        end
      end

      private

      def invoke(&block)
        block.call
      end

    end

  end
end
