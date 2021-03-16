module Taskinator
  module Persistence

    class << self
      def processes_list_key(scope=:shared)
        "taskinator:#{scope}:processes"
      end

      def add_process_to_list(process)
        Taskinator.redis do |conn|
          conn.sadd processes_list_key(process.scope), process.uuid
        end
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
        @base_key ||= 'shared'
      end

      # returns the storage key for the given identifier
      def key_for(uuid)
        "taskinator:#{base_key}:#{uuid}"
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
          conn.pipelined do
            visitor = RedisSerializationVisitor.new(conn, self).visit
            conn.hmset(
              Taskinator::Process.key_for(uuid),
              :tasks_count,      visitor.task_count,
              :tasks_failed,     0,
              :tasks_processing, 0,
              :tasks_completed,  0,
              :tasks_cancelled,  0,
            )
            true
          end
        end
      end

      def to_xml
        builder = ::Builder::XmlMarkup.new
        builder.instruct!
        builder.tag!('process', :key => self.key) do |xml|
          XmlSerializationVisitor.new(xml, self).visit
        end
        builder
      end

      # the persistence key
      def key
        @key ||= self.class.key_for(self.uuid)
      end

      # the root process uuid associated with this process or task
      def process_uuid
        @process_uuid ||= Taskinator.redis do |conn|
          conn.hget(self.key, :process_uuid)
        end
      end

      # the root process persistence key associated with this process or task
      def process_key
        @process_key ||= Taskinator::Process.key_for(process_uuid)
      end

      # retrieves the workflow state
      # this method is called from the workflow gem
      def load_workflow_state
        state = Taskinator.redis do |conn|
          conn.hget(self.key, :state) || 'initial'
        end
        state.to_sym
      end

      # persists the workflow state
      # this method is called from the workflow gem
      def persist_workflow_state(new_state)
        @updated_at = Time.now.utc
        Taskinator.redis do |conn|
          process_key = self.process_key
          conn.multi do
            conn.hmset(
              self.key,
              :state, new_state,
              :updated_at, @updated_at
            )

            # also update the "root" process
            conn.hset(
              process_key,
              :updated_at, @updated_at
            )
          end
        end
        new_state
      end

      # persists the error information
      def fail(error=nil)
        return unless error && error.is_a?(Exception)

        Taskinator.redis do |conn|
          conn.hmset(
            self.key,
            :error_type, error.class.name,
            :error_message, error.message,
            :error_backtrace, JSON.generate(error.backtrace || []),
            :updated_at, Time.now.utc
          )
        end
      end

      # retrieves the error type, message and backtrace
      # and returns an array with 3 subscripts respectively
      def error
        @error ||= Taskinator.redis do |conn|
          error_type, error_message, error_backtrace =
            conn.hmget(self.key, :error_type, :error_message, :error_backtrace)

          [error_type, error_message, JSON.parse(error_backtrace || '[]')]
        end
      end

      def tasks_count
        @tasks_count ||= begin
          count = Taskinator.redis do |conn|
            conn.hget self.process_key, :tasks_count
          end
          count.to_i
        end
      end

      %w(
        failed
        cancelled
        processing
        completed
      ).each do |status|

        define_method "count_#{status}" do
          count = Taskinator.redis do |conn|
            conn.hget self.process_key, "tasks_#{status}"
          end
          count.to_i
        end

        define_method "incr_#{status}" do
          Taskinator.redis do |conn|
            process_key = self.process_key
            conn.multi do
              conn.hincrby process_key, "tasks_#{status}", 1
              conn.hset process_key, :updated_at, Time.now.utc
            end
          end
        end

        define_method "percentage_#{status}" do
          tasks_count > 0 ? (send("count_#{status}") / tasks_count.to_f) * 100.0 : 0.0
        end

      end

      def deincr_pending_tasks
        Taskinator.redis do |conn|
          conn.incrby("#{key}.pending", -1)
        end
      end

      # retrieves the process options of the root process
      # this is so that meta data of the process can be maintained
      # and accessible to instrumentation subscribers
      def process_options
        @process_options ||= begin
          yaml = Taskinator.redis do |conn|
            conn.hget(self.process_key, :options)
          end
          yaml ? Taskinator::Persistence.deserialize(yaml) : {}
        end
      end

      EXPIRE_IN = 30 * 60 # 30 minutes

      def cleanup(expire_in=EXPIRE_IN)
        Taskinator.redis do |conn|

          # use the "clean up" visitor
          RedisCleanupVisitor.new(conn, self, expire_in).visit

          # remove from the list
          conn.srem(Persistence.processes_list_key(scope), uuid)

        end
      end

    end

    class RedisSerializationVisitor < Taskinator::Visitor::Base

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

        # add the default state
        @hmset += [:state, :initial]

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
        tasks.each do |task|
          RedisSerializationVisitor.new(@conn, task, @base_visitor).visit
          @conn.rpush "#{@key}:tasks", task.uuid
          unless task.is_a?(Task::SubProcess)
            incr_task_count unless self == @base_visitor
            @base_visitor.incr_task_count
          end
        end
        @conn.set("#{@key}.count", tasks.count)
        @conn.set("#{@key}.pending", tasks.count)
      end

      def visit_attribute(attribute)
        value = @instance.send(attribute)
        @hmset += [attribute, value] if value
      end

      def visit_attribute_time(attribute)
        visit_attribute(attribute)
      end

      def visit_attribute_enum(attribute, type)
        visit_attribute(attribute)
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

        # greater than 2 MB?
        if (yaml.bytesize / (1024.0**2)) > 2
          Taskinator.logger.warn("Large argument data detected for '#{self.to_s}'. Consider using intrinsic types instead, or try to reduce the amount of data provided.")
        end

        @hmset += [attribute, yaml]
      end

      def task_count
        @task_count
      end

      def incr_task_count
        @task_count += 1
      end
    end

    class XmlSerializationVisitor < Taskinator::Visitor::Base

      #
      # the redis connection is passed in since it is
      # in the multi statement mode in order to produce
      # one roundtrip to the redis server
      #

      attr_reader :builder
      attr_reader :instance

      def initialize(builder, instance, base_visitor=self)
        @builder      = builder
        @instance     = instance
        @key          = instance.key
        @root         = base_visitor.instance
        @base_visitor = base_visitor
        @task_count   = 0
      end

      # the starting point for serializing the instance
      def visit
        @attributes = []
        @attributes << [:type, @instance.class.name]
        @attributes << [:process_uuid, @root.uuid]
        @attributes << [:state, :initial]

        @instance.accept(self)

        @attributes << [:task_count, @task_count]

        @attributes.each do |(name, value)|
          builder.tag!('attribute', name => value)
        end

        self
      end

      def visit_process(attribute)
        process = @instance.send(attribute)
        if process
          @attributes << [attribute, process.uuid]

          builder.tag!('process', :key => process.key) do |xml|
            XmlSerializationVisitor.new(xml, process, @base_visitor).visit
          end
        end
      end

      def visit_tasks(tasks)
        builder.tag!('tasks', :count => tasks.count) do |xml|
          tasks.each do |task|
            xml.tag!('task', :key => task.key) do |xml2|
              XmlSerializationVisitor.new(xml2, task, @base_visitor).visit
              unless task.is_a?(Task::SubProcess)
                incr_task_count unless self == @base_visitor
                @base_visitor.incr_task_count
              end
            end
          end
        end
      end

      def visit_attribute(attribute)
        value = @instance.send(attribute)
        @attributes << [attribute, value] if value
      end

      def visit_attribute_time(attribute)
        visit_attribute(attribute)
      end

      def visit_attribute_enum(attribute, type)
        visit_attribute(attribute)
      end

      def visit_process_reference(attribute)
        process = @instance.send(attribute)
        @attributes << [attribute, process.uuid] if process
      end

      def visit_task_reference(attribute)
        task = @instance.send(attribute)
        @attributes << [attribute, task.uuid] if task
      end

      def visit_type(attribute)
        type = @instance.send(attribute)
        @attributes << [attribute, type.name] if type
      end

      def visit_args(attribute)
        values = @instance.send(attribute)
        yaml = Taskinator::Persistence.serialize(values)

        # greater than 2 MB?
        if (yaml.bytesize / (1024.0**2)) > 2
          Taskinator.logger.warn("Large argument data detected for '#{self.to_s}'. Consider using intrinsic types instead, or try to reduce the amount of data provided.")
        end

        @attributes << [attribute, yaml]
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
          tasks.attach(lazy_instance_for(Task, uuid), conn.get("#{@key}.count").to_i) if uuid
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
        if value
          # converted block given?
          if block_given?
            @instance.instance_variable_set("@#{attribute}", yield(value))
          else
            @instance.instance_variable_set("@#{attribute}", value)
          end
        end
      end

      def visit_attribute_time(attribute)
        visit_attribute(attribute) do |value|
          Time.parse(value)
        end
      end

      # NB: assumes the enum type's members have integer values!
      def visit_attribute_enum(attribute, type)
        visit_attribute(attribute) do |value|
          const_value = type.constants.select {|c| type.const_get(c) == value.to_i }.first
          const_value ?
            type.const_get(const_value) :
            (defined?(type::Default) ? type::Default : nil)
        end
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
        type = Taskinator.redis do |conn|
          conn.hget(base.key_for(uuid), :type)
        end
        klass = Kernel.const_get(type)
        LazyLoader.new(klass, uuid, @instance_cache)
      end
    end

    class RedisCleanupVisitor < Taskinator::Visitor::Base

      attr_reader :instance
      attr_reader :expire_in # seconds

      def initialize(conn, instance, expire_in)
        @conn = conn
        @instance = instance
        @expire_in = expire_in.to_i
        @key = instance.key
      end

      def visit
        @instance.accept(self)
        @conn.expire(@key, expire_in)
      end

      def visit_process(attribute)
        process = @instance.send(attribute)
        RedisCleanupVisitor.new(@conn, process, expire_in).visit if process
      end

      def visit_tasks(tasks)
        @conn.expire "#{@key}:tasks", expire_in
        @conn.expire "#{@key}.count", expire_in
        @conn.expire "#{@key}.pending", expire_in
        tasks.each do |task|
          RedisCleanupVisitor.new(@conn, task, expire_in).visit
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

      def initialize(type, uuid, instance_cache={})
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

    class << self
      def serialize(values)
        # special case, convert models to global id's
        if values.is_a?(Array)
          values = values.collect {|value|
            value.respond_to?(:to_global_id) ? value.to_global_id : value
          }
        elsif values.is_a?(Hash)
          values.each {|key, value|
            values[key] = value.to_global_id if value.respond_to?(:to_global_id)
          }
        elsif values.respond_to?(:to_global_id)
          values = values.to_global_id
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
