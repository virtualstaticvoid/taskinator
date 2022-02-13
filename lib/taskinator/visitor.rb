module Taskinator
  module Visitor
    class Base
      def visit_process(attribute)
      end

      def visit_tasks(tasks)
      end

      def visit_on_completed_tasks(tasks)
      end

      def visit_on_failed_tasks(tasks)
      end

      def visit_attribute(attribute)
      end

      def visit_attribute_time(attribute)
      end

      def visit_attribute_enum(attribute, type)
      end

      def visit_process_reference(attribute)
      end

      def visit_task_reference(attribute)
      end

      def visit_type(attribute)
      end

      def visit_args(attribute)
      end

      def task_count
        # return the total count of all tasks
      end
    end
  end
end
