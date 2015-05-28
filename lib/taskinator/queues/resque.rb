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
          :task_queue => :default,
          :job_queue => :default
        }.merge(config)

        ProcessWorker.class_eval do
          @queue = config[:process_queue]
        end

        TaskWorker.class_eval do
          @queue = config[:task_queue]
        end

        JobWorker.class_eval do
          @queue = config[:job_queue]
        end
      end

      def enqueue_process(process)
        queue = process.queue || Resque.queue_from_class(ProcessWorker)
        Resque.enqueue_to(queue, ProcessWorker, process.uuid)
      end

      def enqueue_task(task)
        queue = task.queue || Resque.queue_from_class(TaskWorker)
        Resque.enqueue_to(queue, TaskWorker, task.uuid)
      end

      def enqueue_job(job)
        queue = job.queue ||
                  Resque.queue_from_class(job.job) ||
                    Resque.queue_from_class(JobWorker)

        Resque.enqueue_to(queue, JobWorker, job.uuid)
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

      class JobWorker
        def self.perform(job_uuid)
          Taskinator::JobWorker.new(job_uuid).perform do |job, args|
            job.perform(*args)
          end
        end
      end
    end
  end
end
