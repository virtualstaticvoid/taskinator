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
          :task_queue => :default,
          :job_queue => :default
        }.merge(config)

        ProcessWorker.class_eval do
          sidekiq_options :queue => config[:process_queue]
        end

        TaskWorker.class_eval do
          sidekiq_options :queue => config[:task_queue]
        end

        JobWorker.class_eval do
          sidekiq_options :queue => config[:job_queue]
        end
      end

      def enqueue_process(process)
        JobWorker.get_sidekiq_options.merge!('queue' => process.queue) if process.queue
        ProcessWorker.perform_async(process.uuid)
      end

      def enqueue_task(task)
        JobWorker.get_sidekiq_options.merge!('queue' => task.queue) if task.queue
        TaskWorker.perform_async(task.uuid)
      end

      def enqueue_job(job)
        queue = job.queue || job.job.get_sidekiq_options['queue']
        JobWorker.get_sidekiq_options.merge!('queue' => queue) if queue
        JobWorker.perform_async(job.uuid)
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

      class JobWorker
        include ::Sidekiq::Worker

        def perform(job_uuid)
          Taskinator::JobWorker.new(job_uuid).perform do |job, args|
            job.new.perform(*args)
          end
        end
      end
    end
  end
end
