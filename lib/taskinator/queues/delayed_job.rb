module Taskinator
  module Queues

    # https://github.com/collectiveidea/delayed_job

    def self.create_delayed_job_adapter(config={})
      DelayedJobAdapter.new(config)
    end

    class DelayedJobAdapter
      def initialize(config={})
        @config = Taskinator::Queues::DefaultConfig.merge(config)
      end

      def enqueue_create_process(definition, uuid, args)
        queue = definition.queue || @config[:definition_queue]
        ::Delayed::Job.enqueue CreateProcessWorker.new(definition.name, uuid, Taskinator::Persistence.serialize(args)), :queue => queue
      end

      def enqueue_task(task)
        queue = task.queue || @config[:task_queue]
        ::Delayed::Job.enqueue TaskWorker.new(task.uuid), :queue => queue
      end

      CreateProcessWorker = Struct.new(:definition_name, :uuid, :args) do
        def perform
          Taskinator::CreateProcessWorker.new(definition_name, uuid, args).perform
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
