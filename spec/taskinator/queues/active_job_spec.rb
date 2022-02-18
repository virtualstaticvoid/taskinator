require 'spec_helper'

describe Taskinator::Queues::ActiveJobAdapter, :active_job do

  it_should_behave_like "a queue adapter", :active_job, Taskinator::Queues::ActiveJobAdapter

  let(:adapter) { Taskinator::Queues::ActiveJobAdapter }
  let(:uuid) {  Taskinator.generate_uuid }

  subject { adapter.new }

  describe "CreateProcessWorker" do
    let(:args) { Taskinator::Persistence.serialize(:foo => :bar) }

    it "enqueues" do
      worker = adapter::CreateProcessWorker
      definition = MockDefinition.create
      subject.enqueue_create_process(definition, uuid, :foo => :bar)

      expect(worker).to have_been_enqueued.with(definition.name, uuid, args)
    end

    it "enqueues to specified queue" do
      worker = adapter::CreateProcessWorker
      definition = MockDefinition.create(:other)

      subject.enqueue_create_process(definition, uuid, :foo => :bar)

      expect(worker).to have_been_enqueued.with(definition.name, uuid, args).on_queue(:other)
    end

    it "calls worker" do
      expect_any_instance_of(Taskinator::CreateProcessWorker).to receive(:perform)
      adapter::CreateProcessWorker.new.perform(MockDefinition.create.name, uuid, args)
    end
  end

  describe "TaskWorker" do
    it "enqueues tasks" do
      worker = adapter::TaskWorker
      subject.enqueue_task(double('task', :uuid => uuid, :queue => nil))

      expect(worker).to have_been_enqueued.with(uuid)
    end

    it "enqueues task to specified queue" do
      worker = adapter::TaskWorker
      subject.enqueue_task(double('task', :uuid => uuid, :queue => :other))

      expect(worker).to have_been_enqueued.with(uuid).on_queue(:other)
    end

    it "calls task worker" do
      expect_any_instance_of(Taskinator::TaskWorker).to receive(:perform)
      adapter::TaskWorker.new.perform(uuid)
    end
  end

end
