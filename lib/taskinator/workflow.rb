module Taskinator
  module Workflow

    def current_state
      @current_state ||= load_workflow_state
    end

    def current_state=(new_state)
      return if new_state == @current_state
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
