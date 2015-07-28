module Taskinator
  module Queues

    def self.create_test_queue_adapter(config={})
      TestQueueAdapter.new
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
  end
end
