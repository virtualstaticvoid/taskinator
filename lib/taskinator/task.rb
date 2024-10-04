module Taskinator
  class Task
    include ::Comparable

    include Workflow
    include Persistence
    include Instrumentation

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

      def define_hook_task(process, method, args, options={})
        Hook.new(process, method, args, options)
      end
    end

    attr_reader :process
    attr_reader :definition
    attr_reader :uuid
    attr_reader :options
    attr_reader :queue
    attr_reader :created_at
    attr_reader :updated_at

    # the next task in the sequence
    attr_accessor :next

    def initialize(process, options={})
      raise ArgumentError, 'process' if process.nil? || !process.is_a?(Process)

      @uuid = "#{process.uuid}:task:#{Taskinator.generate_uuid}"
      @process = process
      @definition = process.definition
      @options = options
      @queue = options.delete(:queue)
      @created_at = Time.now.utc
      @updated_at = created_at
      @current_state = :initial
    end

    def accept(visitor)
      visitor.visit_attribute(:uuid)
      visitor.visit_process_reference(:process)
      visitor.visit_type(:definition)
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

    def enqueue!
      return if paused? || cancelled?

      transition(:enqueued) do
        instrument('taskinator.task.enqueued', enqueued_payload) do
          enqueue
        end
      end
    end

    def start!
      return if paused? || cancelled?
      self.incr_processing if incr_count?

      transition(:processing) do
        instrument('taskinator.task.processing', processing_payload) do
          # notify the process that this task has started
          process.task_started(self) if notify_process?

          start
        end
      end
    end

    #
    # NOTE: a task can't be paused (it's too difficult to implement)
    #       so rather, the parent process is paused, and the task checks it
    #

    # helper method
    def paused?
      super || process.paused?
    end

    def complete!
      self.incr_completed if incr_count?

      transition(:completed) do
        instrument('taskinator.task.completed', completed_payload) do
          complete if respond_to?(:complete)

          # notify the process that this task has completed
          process.task_completed(self) if notify_process?
        end
      end
    end

    def cancel!
      self.incr_cancelled if incr_count?

      transition(:cancelled) do
        instrument('taskinator.task.cancelled', cancelled_payload) do
          cancel if respond_to?(:cancel)

          # notify the process that this task has cancelled
          process.task_cancelled(self) if notify_process?
        end
      end
    end

    def cancelled?
      super || process.cancelled?
    end

    def fail!(error)
      self.incr_failed if incr_count?

      transition(:failed) do
        instrument('taskinator.task.failed', failed_payload(error)) do
          fail(error) if respond_to?(:fail)

          # notify the process that this task has failed
          process.task_failed(self, error) if notify_process?
        end
      end
    end

    def incr_count?
      true
    end

    def notify_process?
      true
    end

    #--------------------------------------------------
    # subclasses must implement the following methods
    #--------------------------------------------------

    # :nocov:
    def enqueue
      raise NotImplementedError
    end

    def start
      raise NotImplementedError
    end
    # :nocov:

    #--------------------------------------------------
    # and optionally, provide methods:
    #--------------------------------------------------
    #
    #  * cancel
    #  * complete
    #  * fail(error)
    #
    #--------------------------------------------------

    # a task which invokes the specified method on the definition
    # the args must be intrinsic types, since they are serialized to YAML
    class Step < Task
      attr_reader :method
      attr_reader :args

      def initialize(process, method, args, options={})
        super(process, options)

        raise ArgumentError, 'method' if method.nil?
        raise NoMethodError, method unless executor.respond_to?(method)

        @method = method
        @args = args
      end

      def enqueue
        Taskinator.queue.enqueue_task(self)
      end

      def start
        executor.send(method, *args)
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
        visitor.visit_attribute(:method)
        visitor.visit_args(:args)
      end

      def executor
        @executor ||= Taskinator::Executor.new(definition, self)
      end

      def inspect
        %(#<#{self.class.name}:0x#{self.__id__.to_s(16)} uuid="#{uuid}", definition=:#{definition}, method=:#{method}, args=#{args}, current_state=:#{current_state}>)
      end
    end

    #--------------------------------------------------

    # a task which invokes the specified background job
    # the args must be intrinsic types, since they are serialized to YAML
    class Job < Task
      attr_reader :job
      attr_reader :args

      def initialize(process, job, args, options={})
        super(process, options)

        raise ArgumentError, 'job' if job.nil?
        raise ArgumentError, 'job' unless job.methods.include?(:perform) || job.instance_methods.include?(:perform)

        @job = job
        @args = args
      end

      def enqueue
        Taskinator.queue.enqueue_task(self)
      end

      def start
        # NNB: if other job types are required, may need to implement how they get invoked here!

        if job.respond_to?(:perform)
          # resque
          job.perform(*args)
        else
          # delayedjob and sidekiq
          job.new.perform(*args)
        end

        # ASSUMPTION: when the job returns, the task is considered to be complete
        complete!

      rescue => e
        Taskinator.logger.error(e)
        Taskinator.logger.debug(e.backtrace)
        fail!(e)
        raise e
      end

      def accept(visitor)
        super
        visitor.visit_type(:job)
        visitor.visit_args(:args)
      end

      def inspect
        %(#<#{self.class.name}:0x#{self.__id__.to_s(16)} uuid="#{uuid}", definition=:#{definition}, job=#{job}, args=#{args}, current_state=:#{current_state}>)
      end
    end

    #--------------------------------------------------

    # a task which delegates to another process
    class SubProcess < Task
      attr_reader :sub_process

      # NOTE: also wraps sequential and concurrent processes

      def initialize(process, sub_process, options={})
        super(process, options)
        raise ArgumentError, 'sub_process' if sub_process.nil? || !sub_process.is_a?(Process)

        @sub_process = sub_process
        @sub_process.parent = self
      end

      def enqueue
        sub_process.enqueue!
      end

      def start
        sub_process.start!

      rescue => e
        Taskinator.logger.error(e)
        Taskinator.logger.debug(e.backtrace)
        fail!(e)
        raise e
      end

      def incr_count?
        # subprocess tasks aren't included in the total count of tasks
        # since they simply delegate to the tasks of the respective subprocess definition
        false
      end

      def accept(visitor)
        super
        visitor.visit_process(:sub_process)
      end

      def inspect
        %(#<#{self.class.name}:0x#{self.__id__.to_s(16)} uuid="#{uuid}", definition=:#{definition}, sub_process=#{sub_process.inspect}, current_state=:#{current_state}>)
      end
    end

    #--------------------------------------------------

    # a task which invokes the specified method on the definition
    # the task is executed independently of the process, so there isn't any further
    # processing once it completes (or fails)
    # the args must be intrinsic types, since they are serialized to YAML
    class Hook < Task
      attr_reader :method
      attr_reader :args

      def initialize(process, method, args, options={})
        super(process, options)

        raise ArgumentError, 'method' if method.nil?
        raise NoMethodError, method unless executor.respond_to?(method)

        @method = method
        @args = args
      end

      def enqueue
        Taskinator.queue.enqueue_task(self)
      end

      def start
        executor.send(method, *args)
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
        visitor.visit_attribute(:method)
        visitor.visit_args(:args)
      end

      def executor
        @executor ||= Taskinator::Executor.new(definition, self)
      end

      def incr_count?
        false
      end

      def notify_process?
        false
      end

      def inspect
        %(#<#{self.class.name}:0x#{self.__id__.to_s(16)} uuid="#{uuid}", definition=:#{definition}, method=:#{method}, args=#{args}, current_state=:#{current_state}>)
      end
    end
  end
end
