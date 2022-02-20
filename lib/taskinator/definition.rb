require 'taskinator/builder'

module Taskinator
  module Definition

    # errors
    class ProcessUndefinedError < StandardError; end
    class ProcessAlreadyDefinedError < StandardError; end

    # for backward compatibility
    UndefinedProcessError = ProcessUndefinedError

    # defines a process

    def define_sequential_process(*arg_list, &block)
      factory = lambda {|definition, options|
        Process.define_sequential_process_for(definition, options)
      }
      define_process(*arg_list + [factory], &block)
    end

    def define_concurrent_process(*arg_list, &block)
      factory = lambda {|definition, options|
        complete_on = options.delete(:complete_on) || CompleteOn::Default
        Process.define_concurrent_process_for(definition, complete_on, options)
      }
      define_process(*arg_list + [factory], &block)
    end

    def define_process(*arg_list, &block)
      raise ProcessAlreadyDefinedError if respond_to?(:_create_process_)

      factory = arg_list.last.respond_to?(:call) ?
                  arg_list.pop :
                  lambda {|definition, options|
                    Process.define_sequential_process_for(definition, options)
                  }

      # called from respective "create_process" methods
      # parameters can contain options as the last parameter
      define_singleton_method :_create_process_ do |subprocess, *args|
        begin

          # TODO: better validation of arguments

          # FIXME: arg_list should only contain an array of symbols

          raise ArgumentError, "wrong number of arguments (#{args.length} for #{arg_list.length})" if args.length < arg_list.length

          options = (args.last.is_a?(Hash) ? args.last : {})
          options[:scope] ||= :shared

          process = factory.call(self, options)

          # this may take long... up to users definition
          Taskinator.instrumenter.instrument('taskinator.process.created', :uuid => process.uuid, :state => :initial) do
            Builder.new(process, self, *args).instance_eval(&block)
          end

          # only save "root processes"
          unless subprocess

            # instrument separately
            Taskinator.instrumenter.instrument('taskinator.process.saved', :uuid => process.uuid, :state => :initial) do

              # this will visit "sub processes" and persist them too
              process.save

              # add it to the list of "root processes"
              Persistence.add_process_to_list(process)

            end

          end

          # this is the "root" process
          process

        rescue => e
          Taskinator.logger.error(e)
          Taskinator.logger.debug(e.backtrace)
          raise e
        end
      end
    end

    attr_accessor :queue

    #
    # creates an instance of the process
    # NOTE: the supplied @args are serialized and ultimately passed to each method of the defined process
    #
    def create_process(*args)
      assert_valid_process_module
      _create_process_(false, *args)
    end

    #
    # returns the process uuid of the process to be created
    # the process can be retrieved using this uuid by using
    # Taskinator::Process.fetch(uuid)
    #
    def create_process_remotely(*args)
      assert_valid_process_module
      uuid = Taskinator.generate_uuid

      Taskinator.queue.enqueue_create_process(self, uuid, args)

      return uuid
    end

    def create_sub_process(*args)
      assert_valid_process_module
      _create_process_(true, *args)
    end

    private

    def assert_valid_process_module
      raise ProcessUndefinedError unless respond_to?(:_create_process_)
    end

  end
end
