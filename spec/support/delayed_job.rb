# mock version of a delayed backend
module Delayed
  module Job
    def self.queue
      @queue ||= []
    end

    def self.clear_all
      @queue = []
    end

    def self.enqueue(*args)
      queue << args
    end

    # NOTE: expects only one job in the queue, so don't forget to clear down the fake queue before each spec
    def self.contains?(job_class, args=nil, queue_name=:default)
      entry = queue.first
      entry &&
        (entry.first.class == job_class) &&
          (entry.first.to_a == [*args]) &&
            (entry.last[:queue] == queue_name)
    end
  end
end
