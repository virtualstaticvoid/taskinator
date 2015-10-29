require 'spec_helper'

describe Taskinator::Queues::DelayedJobAdapter, :delayed_job do

  it_should_behave_like "a queue adapter", :delayed_job, Taskinator::Queues::DelayedJobAdapter

  let(:adapter) { Taskinator::Queues::DelayedJobAdapter }
  let(:uuid) {  Taskinator.generate_uuid }

  subject { adapter.new }

  describe "CreateProcessWorker" do
    let(:args) { Taskinator::Persistence.serialize(:foo => :bar) }

    it "enqueues" do
      expect {
        subject.enqueue_create_process(MockDefinition.create, uuid, :foo => :bar)
      }.to change(Delayed::Job.queue, :size).by(1)
    end

    it "enqueues to specified queue" do
      definition = MockDefinition.create(:other)
      subject.enqueue_create_process(definition, uuid, :foo => :bar)
      expect(Delayed::Job.contains?(adapter::CreateProcessWorker, [definition.name, uuid, args], :other)).to be
    end

    it "calls worker" do
      expect_any_instance_of(Taskinator::CreateProcessWorker).to receive(:perform)
      adapter::CreateProcessWorker.new(MockDefinition.create.name, uuid, args).perform
    end
  end

  describe "TaskWorker" do
    it "enqueues tasks" do
      expect {
        subject.enqueue_task(double('task', :uuid => uuid, :queue => nil))
      }.to change(Delayed::Job.queue, :size).by(1)
    end

    it "enqueues task to specified queue" do
      subject.enqueue_task(double('task', :uuid => uuid, :queue => :other))
      expect(Delayed::Job.contains?(adapter::TaskWorker, uuid, :other)).to be
    end

    it "calls task worker" do
      expect_any_instance_of(Taskinator::TaskWorker).to receive(:perform)
      adapter::TaskWorker.new(uuid).perform
    end
  end

end
