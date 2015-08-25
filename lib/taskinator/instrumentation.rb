module Taskinator
  module Instrumentation

    def instrument(event, payload={})
      Taskinator.instrumenter.instrument(event, payload) do
        yield
      end
    end

    # helper methods for instrumentation payloads

    def enqueued_payload(additional={})
      payload_for(:enqueued, additional)
    end

    def started_payload(additional={})
      payload_for(:processing, additional)
    end

    def completed_payload(additional={})
      payload_for(:completed, additional)
    end

    def cancelled_payload(additional={})
      payload_for(:cancelled, additional)
    end

    def failed_payload(additional={})
      payload_for(:failed, additional)
    end

    private

    def payload_for(state, additional={})

      # need to cache here, since this method hits redis, so can't be part of multi statement following
      process_key = self.process_key

      tasks_count, completed_count, cancelled_count, failed_count = Taskinator.redis do |conn|
        conn.hmget process_key, :tasks_count, :completed, :cancelled, :failed
      end

      tasks_count = tasks_count.to_f

      return {
        :type                  => self.class.name,
        :process_uuid          => process_uuid,
        :process_options       => process_options,
        :uuid                  => uuid,
        :options               => options,
        :state                 => state,
        :percentage_failed     => (tasks_count > 0) ? (failed_count.to_i    / tasks_count) * 100.0 : 0.0,
        :percentage_cancelled  => (tasks_count > 0) ? (cancelled_count.to_i / tasks_count) * 100.0 : 0.0,
        :percentage_completed  => (tasks_count > 0) ? (completed_count.to_i / tasks_count) * 100.0 : 0.0,
        :instance              => self
      }.merge(additional)

    end

  end
end
