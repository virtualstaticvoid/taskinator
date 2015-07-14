module Taskinator
  class Process
    include ::Comparable
    include ::Workflow

    class << self
      def define_sequential_process_for(definition, options={})
        Process::Sequential.new(definition, options)
      end

      def define_concurrent_process_for(definition, complete_on=CompleteOn::Default, options={})
        Process::Concurrent.new(definition, complete_on, options)
      end

      def base_key
        'process'
      end
    end

    attr_reader :uuid
    attr_reader :definition
    attr_reader :options
    attr_reader :queue

    # in the case of sub process tasks, the containing task
    attr_accessor :parent

    def initialize(definition, options={})
      raise ArgumentError, 'definition' if definition.nil?
      raise ArgumentError, "#{definition.name} does not extend the #{Definition.name} module" unless definition.kind_of?(Definition)

      @uuid = options.delete(:uuid) || SecureRandom.uuid
      @definition = definition
      @options = options
      @queue = options.delete(:queue)
    end

    def tasks
      @tasks ||= Tasks.new
    end

    def accept(visitor)
      visitor.visit_attribute(:uuid)
      visitor.visit_task_reference(:parent)
      visitor.visit_type(:definition)
      visitor.visit_tasks(tasks)
      visitor.visit_args(:options)
      visitor.visit_attribute(:queue)
    end

    def <=>(other)
      uuid <=> other.uuid
    end

    def to_s
      "#<#{self.class.name}:#{uuid}>"
    end

    workflow do
      state :initial do
        event :enqueue, :transitions_to => :enqueued
        event :start, :transitions_to => :processing

        # need to be able to complete, for when there are no tasks
        event :complete, :transitions_to => :completed, :if => :no_tasks_defined?

        event :cancel, :transitions_to => :cancelled
        event :fail, :transitions_to => :failed
      end

      state :enqueued do
        event :start, :transitions_to => :processing
        event :complete, :transitions_to => :completed, :if => :no_tasks_defined?
        event :cancel, :transitions_to => :cancelled
        event :fail, :transitions_to => :failed
      end

      state :processing do
        event :pause, :transitions_to => :paused
        event :complete, :transitions_to => :completed, :if => :tasks_completed?
        event :fail, :transitions_to => :failed
      end

      state :paused do
        event :resume, :transitions_to => :processing
        event :cancel, :transitions_to => :cancelled
        event :fail, :transitions_to => :failed
      end

      state :cancelled
      state :completed
      state :failed

      on_transition do |from, to, event, *args|
        Taskinator.logger.debug("PROCESS: #{self.class.name}:#{uuid} :: #{from} => #{to}")
      end

      on_error do |error, from, to, event, *args|
        Taskinator.logger.error("PROCESS: #{self.class.name}:#{uuid} :: #{error.message}")
        Taskinator.logger.debug(error.backtrace)
        fail!(error)
      end
    end

    def no_tasks_defined?
      tasks.empty?
    end

    def tasks_completed?(*args)
      # subclasses must implement this method
      raise NotImplementedError
    end

    def task_failed(task, error)
      # for now, fail this process
      fail!(error)
    end

    # include after defining the workflow
    # since the load and persist state methods
    # need to override the ones defined by workflow
    include Persistence

    def enqueue
      # don't bother if there aren't any tasks!
      if tasks.empty?
        # simply complete the process...
        complete!
      else
        Taskinator.queue.enqueue_process(self)
      end
    end

    # callback for when the process has completed
    def on_completed_entry(*args)
      # notify the parent task (if there is one) that this process has completed
      # note: parent may be a proxy, so explicity check for nil?
      parent.complete! unless parent.nil?
    end

    # callback for when the process has failed
    def on_failed_entry(*args)
      # notify the parent task (if there is one) that this process has failed
      # note: parent may be a proxy, so explicity check for nil?
      parent.fail!(*args) unless parent.nil?
    end

    class Sequential < Process
      def start
        task = tasks.first
        if task
          task.enqueue!
        else
          complete! # weren't any tasks to start with
        end
      end

      def task_completed(task)
        next_task = task.next
        if next_task
          next_task.enqueue!
        else
          complete! if can_complete?
        end
      end

      def tasks_completed?(*args)
        # TODO: optimize this
        tasks.all?(&:completed?)
      end

      def inspect
        %(#<#{self.class.name}:0x#{self.__id__.to_s(16)} state=:#{current_state.name}, tasks=[#{tasks.inspect}]>)
      end
    end

    class Concurrent < Process
      attr_reader :complete_on

      def initialize(definition, complete_on=CompleteOn::Default, options={})
        super(definition, options)
        @complete_on = complete_on
      end

      def start
        if tasks.empty?
          complete! # weren't any tasks to start with
        else
          tasks.each(&:enqueue!)
        end
      end

      def task_completed(task)
        # when complete on first, then don't bother with subsequent tasks completing
        return if completed? || failed?
        complete! if can_complete?
      end

      def tasks_completed?(*args)
        # TODO: optimize this
        if (complete_on == CompleteOn::First)
          tasks.any?(&:completed?)
        else
          tasks.all?(&:completed?)
        end
      end

      def accept(visitor)
        super
        visitor.visit_attribute(:complete_on)
      end

      def inspect
        %(#<#{self.class.name}:0x#{self.__id__.to_s(16)} state=:#{current_state.name}, complete_on=:#{complete_on}, tasks=[#{tasks.inspect}]>)
      end
    end

    # reloads the process from storage
    # NB: only implemented by LazyLoader so that
    #   the process can be lazy loaded, thereafter
    #    it has no effect
    def reload
      false
    end
  end
end
