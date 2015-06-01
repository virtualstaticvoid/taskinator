module Taskinator
  class ProcessWorker
    attr_reader :uuid

    def initialize(uuid)
      @uuid = uuid
    end

    def perform
      process = Taskinator::Process.fetch(@uuid)
      return if process.paused? || process.cancelled?
      begin
        process.start!
      rescue => e
        Taskinator.logger.error(e)
        process.fail!(e)
        raise e
      end
    end
  end
end
