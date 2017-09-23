require 'spec_helper'

describe Taskinator::Queues::SidekiqAdapter, :sidekiq do

  it_should_behave_like "a queue adapter", :sidekiq, Taskinator::Queues::SidekiqAdapter do
    let(:job) { double('job', :get_sidekiq_options => {}) }
  end

  let(:adapter) { Taskinator::Queues::SidekiqAdapter }
  let(:uuid) {  Taskinator.generate_uuid }

  subject { adapter.new }

  describe "CreateProcessWorker" do
    let(:args) { Taskinator::Persistence.serialize(:foo => :bar) }

    it "enqueues" do
      worker = adapter::CreateProcessWorker
      definition = MockDefinition.create
      subject.enqueue_create_process(definition, uuid, :foo => :bar)
      expect(worker).to have_enqueued_sidekiq_job(definition.name, uuid, args)
    end

    it "enqueues to specified queue" do
      subject.enqueue_create_process(MockDefinition.create(:other), uuid, :foo => :bar)
      expect(adapter::CreateProcessWorker).to be_processed_in_x(:other)
    end

    it "calls worker" do
      definition = MockDefinition.create
      expect_any_instance_of(Taskinator::CreateProcessWorker).to receive(:perform)
      adapter::CreateProcessWorker.new.perform(definition.name, uuid, args)
    end
  end

  describe "ProcessWorker" do
    it "enqueues processes" do
      worker = adapter::ProcessWorker
      process = double('process', :uuid => uuid, :queue => nil)
      subject.enqueue_process(process)
      expect(worker).to have_enqueued_sidekiq_job(process.uuid)
    end

    it "enqueues process to specified queue" do
      subject.enqueue_process(double('process', :uuid => uuid, :queue => :other))
      expect(adapter::ProcessWorker).to be_processed_in_x(:other)
    end

    it "calls process worker" do
      expect_any_instance_of(Taskinator::ProcessWorker).to receive(:perform)
      adapter::ProcessWorker.new.perform(uuid)
    end
  end

  describe "TaskWorker" do
    it "enqueues tasks" do
      worker = adapter::TaskWorker
      task = double('task', :uuid => uuid, :queue => nil)
      subject.enqueue_task(task)
      expect(worker).to have_enqueued_sidekiq_job(task.uuid)
    end

    it "enqueues task to specified queue" do
      subject.enqueue_task(double('task', :uuid => uuid, :queue => :other))
      expect(adapter::TaskWorker).to be_processed_in_x(:other)
    end

    it "calls task worker" do
      expect_any_instance_of(Taskinator::TaskWorker).to receive(:perform)
      adapter::TaskWorker.new.perform(uuid)
    end
  end

end
