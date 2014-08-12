module Taskinator
  module Queues

    # https://github.com/resque/resque

    def self.create_resque_adapter(config={})
      ResqueAdapter.new(config)
    end

    class ResqueAdapter
      def initialize(config={})
        config = {
          :process_queue => :default,
          :task_queue => :default
        }.merge(config)

        ProcessWorker.class_eval do
          @queue = config[:process_queue]
        end

        TaskWorker.class_eval do
          @queue = config[:task_queue]
        end
      end

      def enqueue_process(process)
        Resque.enqueue(ProcessWorker, process.uuid)
      end

      def enqueue_task(task)
        Resque.enqueue(TaskWorker, task.uuid)
      end

      class ProcessWorker
        def self.perform(process_uuid)
          Taskinator::ProcessWorker.new(process_uuid).perform
        end
      end

      class TaskWorker
        def self.perform(task_uuid)
          Taskinator::TaskWorker.new(task_uuid).perform
        end
      end
    end
  end
end
