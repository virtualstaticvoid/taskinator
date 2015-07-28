module Taskinator
  class TaskWorker
    attr_reader :uuid

    def initialize(uuid)
      @uuid = uuid
    end

    def perform
      task = Taskinator::Task.fetch(@uuid)
      return if task.paused? || task.cancelled?
      begin
        task.start!
      rescue => e
        Taskinator.logger.error(e)
        Taskinator.logger.debug(e.backtrace)
        task.fail!(e)
        raise e
      end
    end
  end
end
