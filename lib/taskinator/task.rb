module Taskinator
  class Task
    include ::Comparable
    include ::Workflow

    class << self
      def define_step_task(process, method, args, options={})
        Step.new(process, method, args, options)
      end

      def define_job_task(process, job, args, options={})
        Job.new(process, job, args, options)
      end

      def define_sub_process_task(process, sub_process, options={})
        SubProcess.new(process, sub_process, options)
      end

      def base_key
        'task'
      end
    end

    attr_reader :process
    attr_reader :uuid
    attr_reader :options
    attr_reader :queue

    # the next task in the sequence
    attr_accessor :next

    def initialize(process, options={})
      raise ArgumentError, 'process' if process.nil? || !process.is_a?(Process)

      @uuid = SecureRandom.uuid
      @process = process
      @options = options
      @queue = options.delete(:queue)
    end

    def accept(visitor)
      visitor.visit_attribute(:uuid)
      visitor.visit_process_reference(:process)
      visitor.visit_task_reference(:next)
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
        event :fail, :transitions_to => :failed
      end

      state :enqueued do
        event :start, :transitions_to => :processing

        # need to be able to complete, for when sub-tasks have no tasks
        event :complete, :transitions_to => :completed, :if => :can_complete_task?

        event :fail, :transitions_to => :failed
      end

      state :processing do
        event :complete, :transitions_to => :completed, :if => :can_complete_task?
        event :fail, :transitions_to => :failed
      end

      state :completed
      state :failed

      on_transition do |from, to, event, *args|
        Taskinator.logger.debug("TASK: #{self.class.name}:#{uuid} :: #{from} => #{to}")
      end

      on_error do |error, from, to, event, *args|
        Taskinator.logger.error("TASK: #{self.class.name}:#{uuid} :: #{error.message}")
        Taskinator.logger.debug(error.backtrace)
        fail!(error)
      end
    end

    def can_complete_task?(*args)
      # subclasses must implement this method
      raise NotImplementedError
    end

    # include after defining the workflow
    # since the load and persist state methods
    # need to override the ones defined by workflow
    include Persistence

    def enqueue
      Taskinator.queue.enqueue_task(self)
    end

    # callback for when the task has completed
    def on_completed_entry(*args)
      # notify the process that this task has completed
      process.task_completed(self)
    end

    # callback for when the task has failed
    def on_failed_entry(*args)
      # notify the process that this task has failed
      process.task_failed(self, args.last)
    end

    # helper method, delegating to process
    def paused?
      process.paused?
    end

    # helper method, delegating to process
    def cancelled?
      process.cancelled?
    end

    # a task which invokes the specified method on the definition
    # the args must be intrinsic types, since they are serialized to YAML
    class Step < Task
      attr_reader :definition
      attr_reader :method
      attr_reader :args

      def initialize(process, method, args, options={})
        super(process, options)
        @definition = process.definition  # for convenience

        raise ArgumentError, 'method' if method.nil?
        raise NoMethodError, method unless executor.respond_to?(method)

        @method = method
        @args = args
      end

      def executor
        @executor ||= Taskinator::Executor.new(@definition)
      end

      def start
        # ASSUMPTION: when the method returns, the task is considered to be complete
        executor.send(method, *args)
        @is_complete = true
      end

      # NOTE: this _does not_ work when checking out-of-process
      def can_complete_task?
        defined?(@is_complete) && @is_complete
      end

      def accept(visitor)
        super
        visitor.visit_type(:definition)
        visitor.visit_attribute(:method)
        visitor.visit_args(:args)
      end
    end

    # a task which invokes the specified background job
    # the args must be intrinsic types, since they are serialized to YAML
    class Job < Task
      attr_reader :definition
      attr_reader :job
      attr_reader :args

      def initialize(process, job, args, options={})
        super(process, options)
        @definition = process.definition  # for convenience

        raise ArgumentError, 'job' if job.nil?
        raise ArgumentError, 'job' unless job.methods.include?(:perform) || job.instance_methods.include?(:perform)

        @job = job
        @args = args
      end

      def enqueue
        Taskinator.queue.enqueue_job(self)
      end

      def perform(&block)
        yield(job, args)
        @is_complete = true
      end

      # NOTE: this _does not_ work when checking out-of-process
      def can_complete_task?
        defined?(@is_complete) && @is_complete
      end

      def accept(visitor)
        super
        visitor.visit_type(:definition)
        visitor.visit_type(:job)
        visitor.visit_args(:args)
      end
    end

    # a task which delegates to another process
    class SubProcess < Task
      attr_reader :sub_process

      def initialize(process, sub_process, options={})
        super(process, options)
        raise ArgumentError, 'sub_process' if sub_process.nil? || !sub_process.is_a?(Process)

        @sub_process = sub_process
        @sub_process.parent = self
      end

      def start
        sub_process.start!
      end

      def can_complete_task?
        # NOTE: this works out-of-process, so there isn't any issue
        sub_process.completed?
      end

      def accept(visitor)
        super
        visitor.visit_process(:sub_process)
      end
    end

    # reloads the task from storage
    # NB: only implemented by LazyLoader so that
    #   the task can be lazy loaded, thereafter
    #    it has no effect
    def reload
      false
    end
  end
end
