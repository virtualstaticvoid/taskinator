require 'spec_helper'

describe Taskinator::Queues::DelayedJobAdapter do

  it_should_behave_like "a queue adapter", :delayed_job, Taskinator::Queues::DelayedJobAdapter

  let(:adapter) { Taskinator::Queues::DelayedJobAdapter }
  let(:uuid) {  SecureRandom.uuid }

  subject { adapter.new() }

  it "enqueues processes" do
    worker = adapter::ProcessWorker
    expect {
      subject.enqueue_process(double('process', :uuid => uuid))
    }.to change(Delayed::Job.queue, :size).by(1)
  end

  it "calls process worker" do
    expect_any_instance_of(Taskinator::ProcessWorker).to receive(:perform)
    adapter::ProcessWorker.new(uuid).perform
  end

  it "enqueues tasks" do
    worker = adapter::TaskWorker
    expect {
      subject.enqueue_process(double('task', :uuid => uuid))
    }.to change(Delayed::Job.queue, :size).by(1)
  end

  it "calls task worker" do
    expect_any_instance_of(Taskinator::TaskWorker).to receive(:perform)
    adapter::TaskWorker.new(uuid).perform
  end

end
