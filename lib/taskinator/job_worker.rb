module Taskinator
  class JobWorker
    attr_reader :uuid

    def initialize(uuid)
      @uuid = uuid
    end

    # NB: must be provided a block for the implementation of the job execution
    def perform(&block)
      task = Taskinator::Task.fetch(@uuid)
      return if task.paused? || task.cancelled?
      task.start!
      task.perform(&block)
    end
  end
end
