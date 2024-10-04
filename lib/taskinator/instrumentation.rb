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

    def processing_payload(additional={})
      payload_for(:processing, additional)
    end

    def paused_payload(additional={})
      payload_for(:paused, additional)
    end

    def resumed_payload(additional={})
      payload_for(:resumed, additional)
    end

    def completed_payload(additional={})
      payload_for(:completed, additional)
    end

    def cancelled_payload(additional={})
      payload_for(:cancelled, additional)
    end

    def failed_payload(exception, additional={})
      payload_for(:failed, { :exception => exception.to_s, :backtrace => exception.backtrace }.merge(additional))
    end

    private

    def payload_for(state, additional={})

      # need to cache here, since this method hits redis, so can't be part of multi statement following
      process_key = self.process_key

      count, processing, completed, cancelled, failed = Taskinator.redis do |conn|
        conn.hmget process_key,
                   :tasks_count,
                   :tasks_processing,
                   :tasks_completed,
                   :tasks_cancelled,
                   :tasks_failed
      end

      count = count.to_f

      return OpenStruct.new(
        {
          :type                   => self.class.name,
          :definition             => self.definition.name,
          :process_uuid           => process_uuid,
          :process_options        => process_options.dup,
          :uuid                   => uuid,
          :options                => options.dup,
          :state                  => state,
          :percentage_failed      => (count > 0) ? (failed.to_i     / count) * 100.0 : 0.0,
          :percentage_cancelled   => (count > 0) ? (cancelled.to_i  / count) * 100.0 : 0.0,
          :percentage_processing  => (count > 0) ? (processing.to_i / count) * 100.0 : 0.0,
          :percentage_completed   => (count > 0) ? (completed.to_i  / count) * 100.0 : 0.0,
        }.merge(additional)
      )

    end

  end
end
