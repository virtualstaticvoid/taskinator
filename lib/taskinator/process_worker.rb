module Taskinator
  class ProcessWorker
    attr_reader :uuid

    def initialize(uuid)
      @uuid = uuid
    end

    def perform
      # TODO: build the process, and enqueue it. after it completes, report back to the containing process
    end
  end
end
