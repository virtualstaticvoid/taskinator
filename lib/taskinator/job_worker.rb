module Taskinator
  class JobWorker
    def initialize(uuid)
      @uuid = uuid
    end

    # NB: must be provided a block for the implmentation of the job execution
    def perform(&block)
      task = Taskinator::Task.fetch(@uuid)
      return if task.paused? || task.cancelled?
      begin
        task.start!
        task.perform(&block)
        task.complete!
      rescue Exception => e
        Taskinator.logger.error(e)
        task.fail!(e)
        raise e
      end
    end
  end
end
