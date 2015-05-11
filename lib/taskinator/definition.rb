module Taskinator
  module Definition
    class UndefinedProcessError < RuntimeError; end

    # defines a process
    def define_process(*arg_list, &block)
      define_singleton_method :_create_process_ do |args, options={}|

        # TODO: better validation of arguments
        raise ArgumentError, "wrong number of arguments (#{args.length} for #{arg_list.length})" if args.length < arg_list.length

        process = Process.define_sequential_process_for(self)
        Builder.new(process, self, *args).instance_eval(&block)
        process.save

        # if this is a root process, then add it to the list
        Persistence.add_process_to_list(process) unless options[:subprocess]

        process
      end
    end

    # creates an instance of the process
    # NOTE: the supplied @args are serialized and ultimately passed to each method of the defined process
    def create_process(*args)
      raise UndefinedProcessError unless respond_to?(:_create_process_)
      _create_process_(args)
    end

    def create_sub_process(*args)
      raise UndefinedProcessError unless respond_to?(:_create_process_)
      _create_process_(args, :subprocess => true)
    end
  end
end

require 'taskinator/definition/builder'
