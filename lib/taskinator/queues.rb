module Taskinator
  module Queues

    def self.create_adapter(adapter, config={})
      begin
        send("create_#{adapter}_adapter", config)
      rescue NoMethodError
        raise "The queue adapter `#{adapter}` is not yet supported or it's runtime isn't loaded."
      end
    end

  end
end

require 'taskinator/queues/delayed_job' if defined?(Delayed)
require 'taskinator/queues/resque' if defined?(Resque)
require 'taskinator/queues/sidekiq' if defined?(Sidekiq)
