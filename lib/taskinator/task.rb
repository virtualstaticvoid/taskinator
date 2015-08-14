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
    attr_reader :created_at
    attr_reader :updated_at

    # the next task in the sequence
    attr_accessor :next

    def initialize(process, options={})
      raise ArgumentError, 'process' if process.nil? || !process.is_a?(Process)

      @uuid = SecureRandom.uuid
      @process = process
      @options = options
      @queue = options.delete(:queue)
      @created_at = Time.now.utc
      @updated_at = created_at
    end

    def accept(visitor)
      visitor.visit_attribute(:uuid)
      visitor.visit_process_reference(:process)
      visitor.visit_task_reference(:next)
      visitor.visit_args(:options)
      visitor.visit_attribute(:queue)
      visitor.visit_attribute_time(:created_at)
      visitor.visit_attribute_time(:updated_at)
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
        event :complete, :transitions_to => :completed  # specific to a SubProcess which has no tasks
        event :fail, :transitions_to => :failed
      end

      state :enqueued do
        event :start, :transitions_to => :processing
        event :complete, :transitions_to => :completed
        event :fail, :transitions_to => :failed
      end

      state :processing do
        event :complete, :transitions_to => :completed
        event :fail, :transitions_to => :failed
      end

      state :completed
      state :failed

      on_transition do |from, to, event, *args|
        Taskinator.logger.debug("TASK: #{self.class.name}:#{uuid} :: #{from} => #{to}")
      end

    end

    # include after defining the workflow
    # since the load and persist state methods
    # need to override the ones defined by workflow
    include Persistence

    def complete
      instrument('taskinator.task.completed') do
        # notify the process that this task has completed
        process.task_completed(self)
        self.incr_completed
      end
    end

    # callback for when the task has failed
    def on_failed_entry(*args)
      instrument('taskinator.task.failed') do
        self.incr_failed
        # notify the process that this task has failed
        process.task_failed(self, args.last)
      end
    end

    # callback for when the task has cancelled
    def on_cancelled_entry(*args)
      instrument('taskinator.task.cancelled') do
        self.incr_cancelled
      end
    end

    # helper method, delegating to process
    def paused?
      process.paused?
    end

    # helper method, delegating to process
    def cancelled?
      process.cancelled?
    end

    include Instrumentation

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

      def enqueue
        instrument('taskinator.task.enqueued') do
          Taskinator.queue.enqueue_task(self)
        end
      end

      def start
        instrument('taskinator.task.started') do
          executor.send(method, *args)
        end
        # ASSUMPTION: when the method returns, the task is considered to be complete
        complete!

      rescue => e
        Taskinator.logger.error(e)
        Taskinator.logger.debug(e.backtrace)
        fail!(e)
        raise e
      end

      def accept(visitor)
        super
        visitor.visit_type(:definition)
        visitor.visit_attribute(:method)
        visitor.visit_args(:args)
      end

      def executor
        @executor ||= Taskinator::Executor.new(@definition, self)
      end

      def inspect
        %(#<#{self.class.name}:0x#{self.__id__.to_s(16)} uuid="#{uuid}", method=:#{method}, args=#{args}, state=:#{current_state.name}>)
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
        instrument('taskinator.task.enqueued') do
          Taskinator.queue.enqueue_job(self)
        end
      end

      # can't use the start! method, since a block is required
      def perform
        instrument('taskinator.task.started') do
          yield(job, args)
        end
        # ASSUMPTION: when the method returns, the task is considered to be complete
        complete!

      rescue => e
        Taskinator.logger.error(e)
        Taskinator.logger.debug(e.backtrace)
        fail!(e)
        raise e
      end

      def accept(visitor)
        super
        visitor.visit_type(:definition)
        visitor.visit_type(:job)
        visitor.visit_args(:args)
      end

      def inspect
        %(#<#{self.class.name}:0x#{self.__id__.to_s(16)} uuid="#{uuid}", job=#{job}, args=#{args}, state=:#{current_state.name}>)
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

      def enqueue
        instrument('taskinator.task.enqueued') do
          sub_process.enqueue!
        end
      end

      def start
        instrument('taskinator.task.started') do
          sub_process.start!
        end

      rescue => e
        Taskinator.logger.error(e)
        Taskinator.logger.debug(e.backtrace)
        fail!(e)
        raise e
      end

      def accept(visitor)
        super
        visitor.visit_process(:sub_process)
      end

      def inspect
        %(#<#{self.class.name}:0x#{self.__id__.to_s(16)} uuid="#{uuid}", sub_process=#{sub_process.inspect}, state=:#{current_state.name}>)
      end
    end
  end
end
