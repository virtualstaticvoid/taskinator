require 'spec_helper'

shared_examples_for "a task" do |task_type|

  # NOTE: process and task must be defined by callee

  # let(:process) {}
  # let(:task) {}

  it { expect(task.process).to eq(process)  }
  it { expect(task.uuid).to_not be_nil }
  it { expect(task.name).to eq('name')  }
  it { expect(task.to_s).to match(/#{task.uuid}/) }
  it { expect(task.options).to_not be_nil }

end
