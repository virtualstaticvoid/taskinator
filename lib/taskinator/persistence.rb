module Taskinator
  module Persistence

    class << self
      def add_process_to_list(process)
        Taskinator.redis do |conn|
          conn.sadd "taskinator:#{list_key}", process.uuid
        end
      end

      def list_key
        'processes'
      end
    end

    # mixin logic
    def self.included(klass)
      klass.class_eval do
        extend ClassMethods
        include InstanceMethods
      end
    end

    module ClassMethods

      # class must override this method
      # to provide the base key to use for storing
      # it's instances, and it must be unique!
      def base_key
        raise NotImplementedError
      end

      # returns the storage key for the given identifier
      def key_for(uuid)
        "taskinator:#{base_key}:#{uuid}"
      end

      # retrieves the workflow state for the given identifier
      # this prevents to need to load the entire object when
      # querying for the status of an instance
      def state_for(uuid)
        key = key_for(uuid)
        Taskinator.redis do |conn|
          state = conn.hget(key, :state) || 'initial'
          state.to_sym
        end
      end

      # fetches the instance for given identifier
      # optionally, provide a hash to use for the instance cache
      # this argument is defaulted, so top level callers don't
      # need to provide this.
      def fetch(uuid, instance_cache={})
        key = key_for(uuid)
        if instance_cache.key?(key)
          instance_cache[key]
        else
          instance_cache[key] = RedisDeserializationVisitor.new(key, instance_cache).visit
        end
      end
    end

    module InstanceMethods
      def key
        self.class.key_for(self.uuid)
      end

      def save
        Taskinator.redis do |conn|
          conn.multi do
            RedisSerializationVisitor.new(conn, self).visit
            conn.sadd "taskinator:#{self.class.base_key}", self.uuid
            true
          end
        end
      end

      # retrieves the workflow state
      # this method is called from the workflow gem
      def load_workflow_state
        state = Taskinator.redis do |conn|
          conn.hget(self.key, :state)
        end
        (state || 'initial').to_sym
      end

      # persists the workflow state
      # this method is called from the workflow gem
      def persist_workflow_state(new_state)
        Taskinator.redis do |conn|
          conn.hset(self.key, :state, new_state)
        end
      end

      # persists the error information
      def fail(error)
        Taskinator.redis do |conn|
          conn.hmset(
            self.key,
            :error_type, error.class.name,
            :error_message, error.message,
            :error_backtrace, JSON.generate(error.backtrace)
          )
        end
      end

      # retrieves the error type, message and backtrace
      # and returns an array with 3 subscripts respectively
      def error
        @error ||= Taskinator.redis do |conn|
          error_type, error_message, error_backtrace =
            conn.hmget(self.key, :error_type, :error_message, :error_backtrace)

          [error_type, error_message, JSON.parse(error_backtrace)]
        end
      end
    end

    class RedisSerializationVisitor < Visitor::Base

      #
      # the redis connection is passed in since it is
      # in the multi statement mode in order to produce
      # one roundtrip to the redis server
      #

      def initialize(conn, instance, parent=nil)
        @conn = conn
        @instance = instance
        @key = instance.key
        # @parent = parent        # not using this yet
      end

      # the starting point for serializing the instance
      def visit
        @hmset = []
        @hmset << @key
        @hmset += [:type, @instance.class.name]

        @instance.accept(self)

        # NB: splat args
        @conn.hmset(*@hmset)
      end

      def visit_process(attribute)
        process = @instance.send(attribute)
        if process
          @hmset += [attribute, process.uuid]
          RedisSerializationVisitor.new(@conn, process, @instance).visit
        end
      end

      def visit_tasks(tasks)
        @hmset += [:task_count, tasks.count]
        tasks.each do |task|
          RedisSerializationVisitor.new(@conn, task, @instance).visit
          @conn.rpush "#{@key}:tasks", task.uuid
        end
      end

      def visit_attribute(attribute)
        value = @instance.send(attribute)
        @hmset += [attribute, value] if value
      end

      def visit_process_reference(attribute)
        process = @instance.send(attribute)
        @hmset += [attribute, process.uuid] if process
      end

      def visit_task_reference(attribute)
        task = @instance.send(attribute)
        @hmset += [attribute, task.uuid] if task
      end

      def visit_type(attribute)
        type = @instance.send(attribute)
        @hmset += [attribute, type.name] if type
      end

      def visit_args(attribute)
        values = @instance.send(attribute)

        # special case, convert models to global id's
        if values.is_a?(Array)

          values = values.collect {|value|
            value.respond_to?(:global_id) ? value.global_id : value
          }

        elsif values.is_a?(Hash)

          values.each {|key, value|
            values[key] = value.global_id if value.respond_to?(:global_id)
          }

        end

        @hmset += [attribute, YAML.dump(values)]
      end
    end

    class RedisDeserializationVisitor < Taskinator::Visitor::Base

      #
      # assumption here is that all attributes have a backing instance variable
      # which has the same name as the attribute
      #  E.g. name => @name
      #

      #
      # initialize with the store key for the instance to deserialize
      #
      # optionally, pass in a hash which is used to cache the deserialized
      # instances for the given key
      #
      def initialize(key, instance_cache={})
        @key = key
        @instance_cache = instance_cache

        # pre-load all the attributes to reduce redis hits
        Taskinator.redis do |conn|
          keys, values = conn.multi do
            conn.hkeys(@key)
            conn.hvals(@key)
          end
          @attribute_values = Hash[keys.collect(&:to_sym).zip(values)]
        end
      end

      # the starting point for deserializing the instance
      def visit
        return unless @attribute_values.key?(:type)

        type = @attribute_values[:type]
        klass = Kernel.const_get(type)

        #
        # NOTE:
        #  using Class#allocate here so that the
        #  instance is created without the need to
        #  call the Class#new method which has constructor
        #  arguments which are unknown at this stage
        #
        @instance = klass.allocate
        @instance.accept(self)
        @instance
      end

      def visit_process(attribute)
        uuid = @attribute_values[attribute]
        @instance.instance_variable_set("@#{attribute}", lazy_instance_for(Process, uuid)) if uuid
      end

      def visit_tasks(tasks)
        # tasks are a linked list, so just get the first one
        Taskinator.redis do |conn|
          uuid = conn.lindex("#{@key}:tasks", 0)
          tasks << lazy_instance_for(Task, uuid) if uuid
        end
      end

      def visit_process_reference(attribute)
        uuid = @attribute_values[attribute]
        @instance.instance_variable_set("@#{attribute}", lazy_instance_for(Process, uuid)) if uuid
      end

      def visit_task_reference(attribute)
        uuid = @attribute_values[attribute]
        @instance.instance_variable_set("@#{attribute}", lazy_instance_for(Task, uuid)) if uuid
      end

      def visit_attribute(attribute)
        value = @attribute_values[attribute]
        @instance.instance_variable_set("@#{attribute}", value) if value
      end

      def visit_type(attribute)
        value = @attribute_values[attribute]
        if value
          type = Kernel.const_get(value)
          @instance.instance_variable_set("@#{attribute}", type)
        end
      end

      # deserializes the arguments using YAML#load method
      def visit_args(attribute)
        yaml = @attribute_values[attribute]
        if yaml
          values = YAML.load(yaml)

          # special case for models, so find model
          if values.is_a?(Array)

            values = values.collect {|value|
              # is it a global id?
              value.respond_to?(:model_id) && value.respond_to?(:find) ? value.find : value
            }

          elsif values.is_a?(Hash)

            values.each {|key, value|
              # is it a global id?
              values[key] = value.find if value.respond_to?(:model_id) && value.respond_to?(:find)
            }

          end

          @instance.instance_variable_set("@#{attribute}", values)
        end
      end

    private

      #
      # creates a proxy for the instance which
      # will only fetch the instance when used
      # this offers not only an optimization at load
      # time, but also prevents need to load the entire
      # object graph everytime a worker fetches an
      # arbitrary instance to perform it's work
      #
      def lazy_instance_for(base, uuid)
        Taskinator.redis do |conn|
          type = conn.hget(base.key_for(uuid), :type)
          klass = Kernel.const_get(type)
          LazyLoader.new(klass, uuid, @instance_cache)
        end
      end
    end

    # lazily loads the object specified by the type and uuid
    class LazyLoader < Delegator

      #
      # NOTE: the instance cached is passed from the first
      # deserializer onto the next one, to prevent needing
      # to keep loading the same objects again.
      #
      # E.g. this is useful for tasks which refer to their parent processes
      #

      def initialize(type, uuid, instance_cache)
        @type = type
        @uuid = uuid
        @instance_cache = instance_cache
      end

      def __getobj__
        # only fetch the object as needed
        # and memoize for subsequent calls
        @instance ||= @type.fetch(@uuid, @instance_cache)
      end
    end
  end
end
