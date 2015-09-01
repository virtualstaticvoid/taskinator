require 'spec_helper'

shared_examples_for "a task" do |task_type|

  # NOTE: process and subject must be defined by callee

  it { expect(subject.process).to eq(process)  }
  it { expect(subject.uuid).to_not be_nil }
  it { expect(subject.to_s).to match(/#{subject.uuid}/) }
  it { expect(subject.options).to_not be_nil }

end
