require 'spec_helper'

shared_examples_for "a visitor" do |visitor|

  visitor_methods = visitor.instance_methods

  # visit_process(attribute)
  it { expect(visitor_methods.include?(:visit_process)).to be }

  # visit_tasks(tasks)
  it { expect(visitor_methods.include?(:visit_tasks)).to be }

  # visit_before_started_tasks(tasks)
  it { expect(visitor_methods.include?(:visit_before_started_tasks)).to be }

  # visit_after_completed_tasks(tasks)
  it { expect(visitor_methods.include?(:visit_after_completed_tasks)).to be }

  # visit_after_failed_tasks(tasks)
  it { expect(visitor_methods.include?(:visit_after_failed_tasks)).to be }

  # visit_attribute(attribute)
  it { expect(visitor_methods.include?(:visit_attribute)).to be }

  # visit_attribute_time(attribute)
  it { expect(visitor_methods.include?(:visit_attribute_time)).to be }

  # visit_attribute_enum(attribute, type)
  it { expect(visitor_methods.include?(:visit_attribute_enum)).to be }

  # visit_process_reference(attribute)
  it { expect(visitor_methods.include?(:visit_process_reference)).to be }

  # visit_task_reference(attribute)
  it { expect(visitor_methods.include?(:visit_task_reference)).to be }

  # visit_type(attribute)
  it { expect(visitor_methods.include?(:visit_type)).to be }

  # visit_args(attribute)
  it { expect(visitor_methods.include?(:visit_args)).to be }

  # task_count
  it { expect(visitor_methods.include?(:task_count)).to be }

end
