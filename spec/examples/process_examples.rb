require 'spec_helper'

shared_examples_for "a process" do |process_type|

  # NOTE: definition and subject must be defined by callee

  it { expect(subject.definition).to eq(definition)  }
  it { expect(subject.uuid).to_not be_nil }
  it { expect(subject.to_s).to match(/#{subject.uuid}/) }
  it { expect(subject.options).to_not be_nil }
  it { expect(subject.tasks).to_not be_nil }
  it { expect(subject.on_completed_tasks).to_not be_nil }
  it { expect(subject.on_failed_tasks).to_not be_nil }

end
