module Taskinator
  module Definition
    class Builder

      attr_reader :process
      attr_reader :definition
      attr_reader :args
      attr_reader :builder_options

      def initialize(process, definition, *args)
        @process = process
        @definition = definition
        @builder_options = args.last.is_a?(Hash) ? args.pop : {}
        @args = args
        @executor = Taskinator::Executor.new(@definition)
      end

      def option?(key, &block)
        yield if builder_options[key]
      end

      # defines a sub process of tasks which are executed sequentially
      def sequential(options={}, &block)
        raise ArgumentError, 'block' unless block_given?

        sub_process = Process.define_sequential_process_for(@definition, options)
        task = define_sub_process_task(@process, sub_process, options)
        Builder.new(sub_process, @definition, *@args).instance_eval(&block)
        @process.tasks << task if sub_process.tasks.any?
        nil
      end

      # defines a sub process of tasks which are executed concurrently
      def concurrent(complete_on=CompleteOn::Default, options={}, &block)
        raise ArgumentError, 'block' unless block_given?

        sub_process = Process.define_concurrent_process_for(@definition, complete_on, options)
        task = define_sub_process_task(@process, sub_process, options)
        Builder.new(sub_process, @definition, *@args).instance_eval(&block)
        @process.tasks << task if sub_process.tasks.any?
        nil
      end

      # dynamically defines tasks, using the given @iterator method
      # the definition will be evaluated for each yielded item
      def for_each(method, options={}, &block)
        raise ArgumentError, 'method' if method.nil?
        raise NoMethodError, method unless @executor.respond_to?(method)
        raise ArgumentError, 'block' unless block_given?

        #
        # `for_each` is an exception, since it invokes the definition
        # in order to yield elements to the builder, and any options passed
        # are included with the builder options
        #
        method_args = options.any? ? [*@args, options] : @args
        @executor.send(method, *method_args) do |*args|
          Builder.new(@process, @definition, *args).instance_eval(&block)
        end
        nil
      end

      alias_method :transform, :for_each

      # defines a task which executes the given @method
      def task(method, options={})
        raise ArgumentError, 'method' if method.nil?
        raise NoMethodError, method unless @executor.respond_to?(method)

        define_step_task(@process, method, @args, options)
        nil
      end

      # defines a task which executes the given @job
      # which is expected to implement a perform method either as a class or instance method
      def job(job, options={})
        raise ArgumentError, 'job' if job.nil?
        raise ArgumentError, 'job' unless job.methods.include?(:perform) || job.instance_methods.include?(:perform)

        define_job_task(@process, job, @args, options)
        nil
      end

      # defines a sub process task, for the given @definition
      # the definition specified must have input compatible arguments
      # to the current definition
      def sub_process(definition, options={})
        raise ArgumentError, 'definition' if definition.nil?
        raise ArgumentError, "#{definition.name} does not extend the #{Definition.name} module" unless definition.kind_of?(Definition)

        # TODO: decide whether the sub process to dynamically receive arguments

        sub_process = definition.create_sub_process(*@args, combine_options(options))
        task = define_sub_process_task(@process, sub_process, options)
        Builder.new(sub_process, definition, *@args)
        @process.tasks << task if sub_process.tasks.any?
        nil
      end

    private

      def define_step_task(process, method, args, options={})
        define_task(process) {
          Task.define_step_task(process, method, args, combine_options(options))
        }
      end

      def define_job_task(process, job, args, options={})
        define_task(process) {
          Task.define_job_task(process, job, args, combine_options(options))
        }
      end

      def define_sub_process_task(process, sub_process, options={})
        Task.define_sub_process_task(process, sub_process, combine_options(options))
      end

      def define_task(process)
        process.tasks << task = yield
        task
      end

      def combine_options(options={})
        builder_options.merge(options)
      end

    end
  end
end
