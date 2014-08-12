# mock version of a delayed backend
module Delayed
  module Job
    def self.queue
      @queue ||= []
    end

    def self.enqueue(*args)
      queue << args
    end
  end
end
