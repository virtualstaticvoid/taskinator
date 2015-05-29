module Taskinator
  module Definition
    class UndefinedProcessError < RuntimeError; end

    # defines a process
    def define_process(*arg_list, &block)
      define_singleton_method :_create_process_ do |args, options={}|

        # TODO: better validation of arguments

        # FIXME: arg_list should only contain an array of symbols

        raise ArgumentError, "wrong number of arguments (#{args.length} for #{arg_list.length})" if args.length < arg_list.length

        process = Process.define_sequential_process_for(self, options)
        Builder.new(process, self, *args).instance_eval(&block)
        process.save

        # if this is a root process, then add it to the list
        Persistence.add_process_to_list(process) unless options[:subprocess]

        process
      end
    end

    attr_accessor :queue

    #
    # creates an instance of the process
    # NOTE: the supplied @args are serialized and ultimately passed to each method of the defined process
    #
    def create_process(*args)
      assert_valid_process_module
      _create_process_(args)
    end

    #
    # returns a placeholder process, with the uuid attribute of the
    # actual process. the callee can call `reload` if required to
    # get the actual process, once it has been built by the CreateProcessWorker
    #
    def create_process_async(*args)
      assert_valid_process_module
      uuid = SecureRandom.uuid
      Taskinator.queue.enqueue_create_process(self, uuid, args)

      Taskinator::Persistence::LazyLoader.new(Taskinator::Process, uuid)
    end

    def create_sub_process(*args)
      assert_valid_process_module
      _create_process_(args, :subprocess => true)
    end

    private

    def assert_valid_process_module
      raise UndefinedProcessError unless respond_to?(:_create_process_)
    end

  end
end

require 'taskinator/definition/builder'
