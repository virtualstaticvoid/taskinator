require 'spec_helper'

describe Taskinator::Queues::SidekiqAdapter, :sidekiq do

  it_should_behave_like "a queue adapter", :sidekiq, Taskinator::Queues::SidekiqAdapter do
    let(:job) { double('job', :get_sidekiq_options => {}) }
  end

  let(:adapter) { Taskinator::Queues::SidekiqAdapter }
  let(:uuid) {  SecureRandom.uuid }

  subject { adapter.new }

  describe "CreateProcessWorker" do
    let(:args) { Taskinator::Persistence.serialize(:foo => :bar) }

    it "enqueues" do
      worker = adapter::CreateProcessWorker
      definition = MockDefinition.create
      subject.enqueue_create_process(definition, uuid, :foo => :bar)
      expect(worker).to have_enqueued_job(definition.name, uuid, args)
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

  describe "TaskWorker" do
    it "enqueues tasks" do
      worker = adapter::TaskWorker
      task = double('task', :uuid => uuid, :queue => nil)
      subject.enqueue_task(task)
      expect(worker).to have_enqueued_job(task.uuid)
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

  describe "JobWorker" do
    it "enqueues jobs" do
      worker = adapter::JobWorker

      job = double('job', :get_sidekiq_options => {})
      job_task = double('job_task', :uuid => uuid, :job => job, :queue => nil)

      subject.enqueue_job(job_task)
      expect(worker).to have_enqueued_job(job_task.uuid)
    end

    it "enqueues job to queue of the job class" do
      job = double('job', :get_sidekiq_options => {:queue => :job})
      job_task = double('job_task', :uuid => uuid, :job => job, :queue => nil)
      subject.enqueue_job(job_task)

      expect(adapter::JobWorker).to be_processed_in_x(:job)
    end

    it "enqueues job to specified queue" do
      job = double('job', :get_sidekiq_options => {})
      job_task = double('job_task', :uuid => uuid, :job => job, :queue => :other)
      subject.enqueue_job(job_task)

      expect(adapter::JobWorker).to be_processed_in_x(:other)
    end

    it "calls job worker" do
      expect_any_instance_of(Taskinator::JobWorker).to receive(:perform)
      adapter::JobWorker.new.perform(uuid)
    end

    let(:definition) { TestDefinition }

    it "performs invocation on job" do
      args = {:a => 1}
      job = double('job')
      expect(job).to receive(:perform).with(*args)

      job_class = double('job_class', :get_sidekiq_options => {}, :instance_methods => [:perform])
      allow(job_class).to receive(:new) { job }

      process = Taskinator::Process::Sequential.new(definition)
      job_task = Taskinator::Task.define_job_task(process, job_class, args)

      allow(Taskinator::Task).to receive(:fetch).with(uuid) { job_task }

      adapter::JobWorker.new.perform(uuid)
    end
  end
end
