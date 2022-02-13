require 'builder'

module Taskinator
  module Visitor
    class XmlVisitor
      class << self
        def to_xml(process)
          builder = ::Builder::XmlMarkup.new(:indent => 2)
          builder.instruct!
          builder.tag!('process') do
            XmlVisitor.new(builder, process).visit
          end
        end
      end

      attr_reader :builder
      attr_reader :instance

      def initialize(builder, instance)
        @builder = builder
        @instance = instance
      end

      def visit
        @instance.accept(self)
      end

      def write_error(error)
        return unless error[0]
        builder.tag!('error', :type => error[0]) do
          builder.message(error[1])
          builder.cdata!(error[2].join("\n"))
        end
      end

      def visit_process(attribute)
        process = @instance.send(attribute)
        if process
          p = process.__getobj__

          attribs = {
            :type => p.class.name,
            :current_state => p.current_state
          }

          builder.tag!('process', attribs) do
            XmlVisitor.new(builder, p).visit
            write_error(p.error)
          end
        end
      end

      def visit_tasks(tasks)
        visit_tasks_set(tasks, 'tasks')
      end

      def visit_on_completed_tasks(tasks)
        visit_tasks_set(tasks, 'on_completed_tasks')
      end

      def visit_on_failed_tasks(tasks)
        visit_tasks_set(tasks, 'on_failed_tasks')
      end

      def visit_attribute(attribute)
        value = @instance.send(attribute)
        builder.tag!('attribute', :name => attribute, :value => value) if value
      end

      def visit_attribute_time(attribute)
        visit_attribute(attribute)
      end

      def visit_attribute_enum(attribute, type)
        visit_attribute(attribute)
      end

      def visit_process_reference(attribute)
        process = @instance.send(attribute)
        builder.tag!('attribute_ref', { :name => attribute, :type => process.__getobj__.class.name, :value => process.uuid }) if process
      end

      def visit_task_reference(attribute)
        task = @instance.send(attribute)
        builder.tag!('attribute_ref', { :name => attribute, :type => task.__getobj__.class.name, :value => task.uuid }) if task
      end

      def visit_type(attribute)
        type = @instance.send(attribute)
        builder.tag!('attribute', { :name => attribute, :value => type.name })
      end

      def visit_args(attribute)
        values = @instance.send(attribute)

        builder.tag!('attribute', :name => attribute) do
          builder.cdata!(values.to_json)
        end if values && !values.empty?
      end

      def task_count
      end

      private

      def visit_tasks_set(tasks, set)
        tasks.each do |task|
          t = task.__getobj__

          attribs = {
            :type => t.class.name,
            :current_state => t.current_state
          }

          builder.tag!(set, attribs) do
            XmlVisitor.new(builder, t).visit
            write_error(t.error)
          end
        end
      end

    end
  end
end
