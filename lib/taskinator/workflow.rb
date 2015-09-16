module Taskinator
  module Workflow

    def current_state
      # NB: don't memoize this value (i.e. re-read it each time)
      @current_state = load_workflow_state
    end

    def current_state=(new_state)
      @current_state = persist_workflow_state(new_state)
    end

    def transition(new_state)
      self.current_state = new_state
      yield if block_given?
      current_state
    end

    %i(
      initial
      enqueued
      processing
      paused
      resumed
      completed
      cancelled
      failed
    ).each do |state|

      define_method :"#{state}?" do
        current_state == state
      end

    end

  end
end
