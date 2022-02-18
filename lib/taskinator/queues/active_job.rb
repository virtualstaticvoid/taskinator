module Taskinator
  module Queues

    # https://guides.rubyonrails.org/active_job_basics.html

    def self.create_active_job_adapter(config={})
      ActiveJobAdapter.new(config)
    end

    class ActiveJobAdapter
      def initialize(config={})
        @config = Taskinator::Queues::DefaultConfig.merge(config)
      end

      def enqueue_create_process(definition, uuid, args)
        queue = definition.queue || @config[:definition_queue]
        CreateProcessWorker.set(:queue => queue)
          .perform_later(definition.name, uuid, Taskinator::Persistence.serialize(args))
      end

      def enqueue_task(task)
        queue = task.queue || @config[:task_queue]
        TaskWorker.set(:queue => queue)
          .perform_later(task.uuid)
      end

      class CreateProcessWorker < ApplicationJob
        def perform(definition_name, uuid, args)
          Taskinator::CreateProcessWorker.new(definition_name, uuid, args).perform
        end
      end

      class TaskWorker < ApplicationJob
        def perform(task_uuid)
          Taskinator::TaskWorker.new(task_uuid).perform
        end
      end

    end
  end
end
