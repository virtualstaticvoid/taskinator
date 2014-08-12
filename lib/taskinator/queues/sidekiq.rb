module Taskinator
  module Queues

    # https://github.com/mperham/sidekiq

    def self.create_sidekiq_adapter(config={})
      SidekiqAdapter.new(config)
    end

    class SidekiqAdapter
      def initialize(config={})
        config = {
          :process_queue => :default,
          :task_queue => :default
        }.merge(config)

        ProcessWorker.class_eval do
          sidekiq_options :queue => config[:process_queue]
        end

        TaskWorker.class_eval do
          sidekiq_options :queue => config[:task_queue]
        end
      end

      def enqueue_process(process)
        ProcessWorker.perform_async(process.uuid)
      end

      def enqueue_task(task)
        TaskWorker.perform_async(task.uuid)
      end

      class ProcessWorker
        include ::Sidekiq::Worker

        def perform(process_uuid)
          Taskinator::ProcessWorker.new(process_uuid).perform
        end
      end

      class TaskWorker
        include ::Sidekiq::Worker

        def perform(task_uuid)
          Taskinator::TaskWorker.new(task_uuid).perform
        end
      end
    end
  end
end
