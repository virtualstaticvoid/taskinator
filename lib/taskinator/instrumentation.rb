module Taskinator
  module Instrumentation

    def instrument(event, options={})
      Taskinator.instrumenter.instrument(event, instrumentation_payload(options)) do
        yield
      end
    end

    # prepares the meta data for instrumentation events
    def instrumentation_payload(additional={})

      # need to cache here, since this method hits redis, so can't be part of multi statement following
      process_key = self.process_key

      tasks_count, completed_count, cancelled_count, failed_count, created_at, updated_at = Taskinator.redis do |conn|
        conn.hmget process_key, :tasks_count, :completed, :cancelled, :failed, :created_at, :updated_at
      end

      tasks_count = tasks_count.to_f
      completed_percent = tasks_count > 0 ? (completed_count.to_i / tasks_count) * 100.0 : 0.0
      cancelled_percent = tasks_count > 0 ? (cancelled_count.to_i / tasks_count) * 100.0 : 0.0
      failed_percent    = tasks_count > 0 ? (failed_count.to_i    / tasks_count) * 100.0 : 0.0

      return {
        :type                  => self.class.name,
        :process_uuid          => process_uuid,
        :process_options       => process_options,
        :uuid                  => uuid,
        :state                 => (state || :initial),
        :percentage_failed     => failed_percent,
        :percentage_cancelled  => cancelled_percent,
        :percentage_completed  => completed_percent,
        :tasks_count           => tasks_count,
        :created_at            => created_at,
        :updated_at            => updated_at
      }.merge(additional)

    end

  end
end
