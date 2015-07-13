require 'spec_helper'

describe Taskinator::Visitor::Base do

  it { respond_to(:visit_process) }
  it { respond_to(:visit_tasks) }
  it { respond_to(:visit_attribute) }
  it { respond_to(:visit_process_reference) }
  it { respond_to(:visit_task_reference) }
  it { respond_to(:visit_type) }
  it { respond_to(:visit_args) }
  it { respond_to(:task_count) }

end
