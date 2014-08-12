require 'spec_helper'

describe Taskinator::Queues::ResqueAdapter do

  it_should_behave_like "a queue adapter", :resque, Taskinator::Queues::ResqueAdapter

  let(:adapter) { Taskinator::Queues::ResqueAdapter }
  let(:uuid) {  SecureRandom.uuid }

  subject { adapter.new() }

  it "enqueues processes" do
    worker = adapter::ProcessWorker
    subject.enqueue_process(double('process', :uuid => uuid))

    expect(worker).to have_queued(uuid)
  end

  it "calls process worker" do
    expect_any_instance_of(Taskinator::ProcessWorker).to receive(:perform)
    adapter::ProcessWorker.perform(uuid)
  end

  it "enqueues tasks" do
    worker = adapter::TaskWorker
    subject.enqueue_task(double('task', :uuid => uuid))

    expect(worker).to have_queued(uuid)
  end

  it "calls task worker" do
    expect_any_instance_of(Taskinator::TaskWorker).to receive(:perform)
    adapter::TaskWorker.perform(uuid)
  end

end
