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
          :task_queue => :default,
          :job_queue => :default,
        }.merge(config)
      end

      def enqueue_process(process)
        ::Delayed::Job.enqueue ProcessWorker.new(process.uuid), :queue => @config[:process_queue]
      end

      def enqueue_task(task)
        ::Delayed::Job.enqueue TaskWorker.new(task.uuid), :queue => @config[:task_queue]
      end

      def enqueue_job(job)
        # delayed jobs don't define the queue so use the configured queue instead
        ::Delayed::Job.enqueue JobWorker.new(job.uuid), :queue => @config[:job_queue]
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

      JobWorker = Struct.new(:job_uuid) do
        def perform
          Taskinator::JobWorker.new(job_uuid).perform do |job, args|
            job.new(*args).perform
          end
        end
      end
    end
  end
end
