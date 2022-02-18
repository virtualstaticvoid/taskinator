require 'spec_helper'

describe Taskinator::Queues::ResqueAdapter, :resque do

  it_should_behave_like "a queue adapter", :resque, Taskinator::Queues::ResqueAdapter

  let(:adapter) { Taskinator::Queues::ResqueAdapter }
  let(:uuid) {  Taskinator.generate_uuid }

  subject { adapter.new }

  describe "CreateProcessWorker" do
    let(:args) { Taskinator::Persistence.serialize(:foo => :bar) }

    it "enqueues" do
      worker = adapter::CreateProcessWorker
      definition = MockDefinition.create
      subject.enqueue_create_process(definition, uuid, :foo => :bar)

      expect(worker).to have_queued(definition.name, uuid, args)
    end

    it "enqueues to specified queue" do
      worker = adapter::CreateProcessWorker
      definition = MockDefinition.create(:other)
      subject.enqueue_create_process(definition, uuid, :foo => :bar)

      expect(worker).to have_queued(definition.name, uuid, args).in(:other)
    end

    it "calls worker" do
      expect_any_instance_of(Taskinator::CreateProcessWorker).to receive(:perform)
      adapter::CreateProcessWorker.perform(MockDefinition.create.name, uuid, args)
    end
  end

  describe "TaskWorker" do
    it "enqueues tasks" do
      worker = adapter::TaskWorker
      subject.enqueue_task(double('task', :uuid => uuid, :queue => nil))

      expect(worker).to have_queued(uuid)
    end

    it "enqueues task to specified queue" do
      worker = adapter::TaskWorker
      subject.enqueue_task(double('task', :uuid => uuid, :queue => :other))

      expect(worker).to have_queued(uuid).in(:other)
    end

    it "calls task worker" do
      expect_any_instance_of(Taskinator::TaskWorker).to receive(:perform)
      adapter::TaskWorker.perform(uuid)
    end
  end

end
