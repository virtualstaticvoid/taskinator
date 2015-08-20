require 'spec_helper'

describe Taskinator::Queues do

  it "raise error for an unknown adapter" do
    expect {
      Taskinator::Queues.create_adapter(:unknown)
    }.to raise_error(StandardError)
  end

  it "passes configuration to adapter initializer" do
    config = {:a => :b, :c => :d}
    expect(Taskinator::Queues).to receive(:create_test_adapter).with(config)

    Taskinator::Queues.create_adapter(:test, config)
  end

end
