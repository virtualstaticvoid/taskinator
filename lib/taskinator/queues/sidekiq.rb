module Taskinator
  module Queues

    # https://github.com/mperham/sidekiq

    def self.create_sidekiq_adapter(config={})
      SidekiqAdapter.new(config)
    end

    class SidekiqAdapter
      def initialize(config={})
        @config = Taskinator::Queues::DefaultConfig.merge(config)
      end

      def enqueue_create_process(definition, uuid, args)
        queue = definition.queue || @config[:definition_queue]
        CreateProcessWorker.client_push('class' => CreateProcessWorker, 'args' => [definition.name, uuid, Taskinator::Persistence.serialize(args)], 'queue' => queue)
      end

      def enqueue_task(task)
        queue = task.queue || @config[:task_queue]
        TaskWorker.client_push('class' => TaskWorker, 'args' => [task.uuid], 'queue' => queue)
      end

      def enqueue_job(job)
        queue = job.queue || job.job.get_sidekiq_options[:queue] || @config[:job_queue]
        JobWorker.client_push('class' => JobWorker, 'args' => [job.uuid], 'queue' => queue)
      end

      class CreateProcessWorker
        include ::Sidekiq::Worker

        def perform(definition_name, uuid, args)
          Taskinator::CreateProcessWorker.new(definition_name, uuid, args).perform
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
