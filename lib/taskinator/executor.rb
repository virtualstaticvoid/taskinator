module Taskinator
  class Executor

    attr_reader :definition
    attr_reader :task

    def initialize(definition, task=nil)
      @definition = definition
      @task = task

      # include the module into the eigen class, so it is only for this instance
      eigen = class << self; self; end
      eigen.send(:include, definition)
    end

    def process_uuid
      task.process_uuid
    end

    def uuid
      task.uuid
    end

    def options
      task.options
    end

  end
end
