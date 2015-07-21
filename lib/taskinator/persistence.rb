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

      def save
        Taskinator.redis do |conn|
          conn.multi do
            visitor = RedisSerializationVisitor.new(conn, self).visit
            conn.hmset(
              "taskinator:#{self.key}",
              :tasks_count,     visitor.task_count,
              :tasks_failed,    0,
              :tasks_completed, 0,
              :tasks_cancelled, 0,
            )
            true
          end
        end
      end

      # this is the persistence key
      def key
        @key ||= self.class.key_for(self.uuid)
      end

      # retrieves the root key associated
      # with the process or task
      def process_key
        @process_key ||= Taskinator.redis do |conn|
          conn.hget(self.key, :process_key)
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
      def fail(error=nil)
        return unless error && error.is_a?(Exception)

        Taskinator.redis do |conn|
          conn.hmset(
            self.key,
            :error_type, error.class.name,
            :error_message, error.message,
            :error_backtrace, JSON.generate(error.backtrace || [])
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

      def tasks_count
        @tasks_count ||= begin
          Taskinator.redis do |conn|
            conn.hget "taskinator:#{self.process_key}", :tasks_count
          end.to_i
        end
      end

      %w(
        failed
        cancelled
        completed
      ).each do |status|

        define_method "count_#{status}" do
          Taskinator.redis do |conn|
            conn.hget "taskinator:#{self.process_key}", status
          end.to_i
        end

        define_method "incr_#{status}" do
          Taskinator.redis do |conn|
            conn.hincrby "taskinator:#{self.process_key}", status, 1
          end
        end

        define_method "percentage_#{status}" do
          tasks_count > 0 ? (send("count_#{status}") / tasks_count.to_f) * 100.0 : 0.0
        end

      end

      def process_options
        @process_options ||= begin
          Taskinator.redis do |conn|
            yaml = conn.hget("taskinator:#{self.process_key}", :options)
            yaml ? Taskinator::Persistence.deserialize(yaml) : {}
          end
        end
      end

      def instrumentation_payload(options={})
        {
          :process_uuid => process_uuid,
          :process_options => process_options,
          :uuid => uuid,
          :percentage_failed => percentage_failed,
          :percentage_cancelled => percentage_cancelled,
          :percentage_completed => percentage_completed
        }.merge(options)
      end

    end

    class RedisSerializationVisitor < Visitor::Base

      #
      # the redis connection is passed in since it is
      # in the multi statement mode in order to produce
      # one roundtrip to the redis server
      #

      attr_reader :instance

      def initialize(conn, instance, base_visitor=self)
        @conn         = conn
        @instance     = instance
        @key          = instance.key
        @root         = base_visitor.instance
        @base_visitor = base_visitor
        @task_count   = 0
      end

      # the starting point for serializing the instance
      def visit
        @hmset = []
        @hmset << @key

        @hmset += [:type, @instance.class.name]

        @instance.accept(self)

        # add the process uuid and root key, for easy access later!
        @hmset += [:process_uuid, @root.uuid]
        @hmset += [:process_key, @root.key]

        # NB: splat args
        @conn.hmset(*@hmset)

        self
      end

      def visit_process(attribute)
        process = @instance.send(attribute)
        if process
          @hmset += [attribute, process.uuid]
          RedisSerializationVisitor.new(@conn, process, @base_visitor).visit
        end
      end

      def visit_tasks(tasks)
        @hmset += [:task_count, tasks.count]  # not used currently, but for informational purposes
        tasks.each do |task|
          RedisSerializationVisitor.new(@conn, task, @base_visitor).visit
          @conn.rpush "#{@key}:tasks", task.uuid
          @base_visitor.incr_task_count unless task.is_a?(Task::SubProcess)
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
        yaml = Taskinator::Persistence.serialize(values)
        @hmset += [attribute, yaml]
      end

      def task_count
        @task_count
      end

      def incr_task_count
        @task_count += 1
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
          values = Taskinator::Persistence.deserialize(yaml)
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
          process_uuid = conn.hget(base.key_for(uuid), :process_uuid)
          process_key = conn.hget(base.key_for(uuid), :process_key)

          klass = Kernel.const_get(type)
          LazyLoader.new(klass, uuid, process_uuid, process_key, @instance_cache)
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

      def initialize(type, uuid, process_uuid, process_key, instance_cache={})
        @type = type
        @uuid = uuid
        @process_uuid = process_uuid
        @process_key = process_key
        @instance_cache = instance_cache
      end

      # shadows the real methods, but will be the same!
      attr_reader :process_uuid
      attr_reader :uuid
      attr_reader :process_key

      # attempts to reload the actual process
      def reload
        @instance = nil
        __getobj__
        @instance ? true : false
      end

      def __getobj__
        # only fetch the object as needed
        # and memoize for subsequent calls
        @instance ||= @type.fetch(@uuid, @instance_cache)
      end
    end

    class << self
      def serialize(values)
        # special case, convert models to global id's
        if values.is_a?(Array)
          values = values.collect {|value|
            value.respond_to?(:global_id) ? value.global_id : value
          }
        elsif values.is_a?(Hash)
          values.each {|key, value|
            values[key] = value.global_id if value.respond_to?(:global_id)
          }
        elsif values.respond_to?(:global_id)
          values = values.global_id
        end
        YAML.dump(values)
      end

      def deserialize(yaml)
        values = YAML.load(yaml)
        if values.is_a?(Array)
          values = values.collect {|value|
            (value.respond_to?(:model_id) && value.respond_to?(:find)) ? value.find : value
          }
        elsif values.is_a?(Hash)
          values.each {|key, value|
            values[key] = value.find if value.respond_to?(:model_id) && value.respond_to?(:find)
          }
        elsif values.respond_to?(:model_id) && values.respond_to?(:find)
          values = values.find
        end
        values
      end
    end

  end
end
