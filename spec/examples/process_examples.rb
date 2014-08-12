require 'spec_helper'

shared_examples_for "a process" do |process_type|

  # NOTE: definition and process must be defined by callee

  # let(:definition) {}
  # let(:process) {}

  it { expect(process.definition).to eq(definition)  }
  it { expect(process.uuid).to_not be_nil }
  it { expect(process.name).to eq('name')  }
  it { expect(process.to_s).to match(/#{process.uuid}/) }
  it { expect(process.options).to_not be_nil }
  it { expect(process.tasks).to_not be_nil }

end
