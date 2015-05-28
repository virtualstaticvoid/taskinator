module Taskinator
  module Queues

    # https://github.com/mperham/sidekiq

    def self.create_sidekiq_adapter(config={})
      SidekiqAdapter.new(config)
    end

    class SidekiqAdapter
      def initialize(config={})
        @config = {
          :process_queue => :default,
          :task_queue => :default,
          :job_queue => :default
        }.merge(config)
      end

      def enqueue_process(process)
        queue = process.queue || @config[:process_queue]
        ProcessWorker.client_push('class' => ProcessWorker, 'args' => [process.uuid], 'queue' => queue)
      end

      def enqueue_task(task)
        queue = task.queue || @config[:task_queue]
        TaskWorker.client_push('class' => TaskWorker, 'args' => [task.uuid], 'queue' => queue)
      end

      def enqueue_job(job)
        queue = job.queue || job.job.get_sidekiq_options[:queue] || @config[:job_queue]
        JobWorker.client_push('class' => JobWorker, 'args' => [job.uuid], 'queue' => queue)
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
