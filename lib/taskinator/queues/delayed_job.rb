module Taskinator
  module Queues

    # https://github.com/collectiveidea/delayed_job

    def self.create_delayed_job_adapter(config={})
      DelayedJobAdapter.new(config)
    end

    class DelayedJobAdapter
      def initialize(config={})
        @config = {
          :process_queue => :default,
          :task_queue => :default
        }.merge(config)
      end

      def enqueue_process(process)
        ::Delayed::Job.enqueue ProcessWorker.new(process.uuid), :queue => @config[:process_queue]
      end

      def enqueue_task(task)
        ::Delayed::Job.enqueue TaskWorker.new(task.uuid), :queue => @config[:task_queue]
      end

      ProcessWorker = Struct.new(:process_uuid) do
        def perform
          Taskinator::ProcessWorker.new(process_uuid).perform
        end
      end

      TaskWorker = Struct.new(:task_uuid) do
        def perform
          Taskinator::TaskWorker.new(task_uuid).perform
        end
      end
    end
  end
end
