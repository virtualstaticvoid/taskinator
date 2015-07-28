module Taskinator
  module Queues

    def self.create_test_queue_adapter(config={})
      TestQueueAdapter.new
    end

    def self.create_test_queue_worker_adapter(config={})
      QueueWorkerAdapter.new
    end

    class TestQueueAdapter

      attr_reader :creates
      attr_reader :tasks
      attr_reader :jobs

      def initialize
        clear
      end

      def clear
        @creates = []
        @tasks = []
        @jobs = []
      end

      def enqueue_create_process(definition, uuid, args)
        @creates << [definition, uuid, args]
      end

      def enqueue_task(task)
        @tasks << task
      end

      def enqueue_job(job)
        @jobs << job
      end

    end

    #
    # this is a synchronous implementation for use in testing
    #
    class QueueWorkerAdapter

      def enqueue_create_process(definition, uuid, args)
        Taskinator::CreateProcessWorker.new(definition.name, uuid, args).perform
      end

      def enqueue_task(task)
        Taskinator::TaskWorker.new(task.uuid).perform
      end

      def enqueue_job(job)
        Taskinator::JobWorker.new(job.uuid).perform
      end

    end

  end
end
