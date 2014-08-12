require 'spec_helper'

describe Taskinator::Queues::SidekiqAdapter do

  it_should_behave_like "a queue adapter", :sidekiq, Taskinator::Queues::SidekiqAdapter

  let(:adapter) { Taskinator::Queues::SidekiqAdapter }
  let(:uuid) {  SecureRandom.uuid }

  subject { adapter.new() }

  it "enqueues processes" do
    worker = adapter::ProcessWorker
    expect {
      subject.enqueue_process(double('process', :uuid => uuid))
    }.to change(worker.jobs, :size).by(1)
  end

  it "calls process worker" do
    expect_any_instance_of(Taskinator::ProcessWorker).to receive(:perform)
    adapter::ProcessWorker.new().perform(uuid)
  end

  it "enqueues tasks" do
    worker = adapter::TaskWorker
    expect {
      subject.enqueue_task(double('task', :uuid => uuid))
    }.to change(worker.jobs, :size).by(1)
  end

  it "calls task worker" do
    expect_any_instance_of(Taskinator::TaskWorker).to receive(:perform)
    adapter::TaskWorker.new().perform(uuid)
  end

end
