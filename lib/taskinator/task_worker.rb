module Taskinator
  class TaskWorker
    attr_reader :uuid

    def initialize(uuid)
      @uuid = uuid
    end

    def perform
      task = Taskinator::Task.fetch(@uuid)
      return if task.paused? || task.cancelled?
      task.start!
    end
  end
end
