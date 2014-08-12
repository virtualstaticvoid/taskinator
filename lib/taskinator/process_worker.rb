module Taskinator
  class ProcessWorker
    def initialize(uuid)
      @uuid = uuid
    end

    def perform
      process = Taskinator::Process.fetch(@uuid)
      return if process.paused? || process.cancelled?
      begin
        process.start!
      rescue Exception => e
        process.fail!(e)
      end
    end
  end
end
