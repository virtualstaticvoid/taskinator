module Taskinator
  module Queues

    def self.create_test_queue_adapter(config={})
      TestQueueAdapter::new()
    end

    class TestQueueAdapter

      attr_reader :processes
      attr_reader :tasks
      attr_reader :jobs

      def initialize
        clear
      end

      def clear
        @processes = []
        @tasks = []
        @jobs = []
      end

      def enqueue_process(process)
        @processes << process
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
