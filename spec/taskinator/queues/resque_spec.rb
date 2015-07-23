require 'spec_helper'

describe Taskinator::Queues::ResqueAdapter, :resque do

  it_should_behave_like "a queue adapter", :resque, Taskinator::Queues::ResqueAdapter

  let(:adapter) { Taskinator::Queues::ResqueAdapter }
  let(:uuid) {  SecureRandom.uuid }

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

  describe "JobWorker" do
    it "enqueues jobs" do
      worker = adapter::JobWorker

      job = double('job')
      job_task = double('job_task', :uuid => uuid, :job => job, :queue => nil)

      subject.enqueue_job(job_task)
      expect(worker).to have_queued(uuid)
    end

    it "enqueues job to queue of the job class" do
      worker = adapter::JobWorker

      job = double('job', :queue => :job)
      job_task = double('job_task', :uuid => uuid, :job => job, :queue => nil)

      subject.enqueue_job(job_task)
      expect(worker).to have_queued(uuid).in(:job)
    end

    it "enqueues job to specified queue" do
      worker = adapter::JobWorker

      job = double('job')
      job_task = double('job_task', :uuid => uuid, :job => job, :queue => :other)

      subject.enqueue_job(job_task)
      expect(worker).to have_queued(uuid).in(:other)
    end

    it "calls job worker" do
      expect_any_instance_of(Taskinator::JobWorker).to receive(:perform)
      adapter::JobWorker.perform(uuid)
    end

    let(:definition) { TestDefinition }

    it "performs invocation on job" do
      args = {:a => 1}
      job_class = double('job_class', :methods => [:perform])
      expect(job_class).to receive(:perform).with(*args)

      process = Taskinator::Process::Sequential.new(definition)
      job_task = Taskinator::Task.define_job_task(process, job_class, args)

      allow(Taskinator::Task).to receive(:fetch).with(uuid) { job_task }

      adapter::JobWorker.perform(uuid)
    end
  end
end
