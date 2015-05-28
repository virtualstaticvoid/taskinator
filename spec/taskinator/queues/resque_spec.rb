require 'spec_helper'

describe Taskinator::Queues::ResqueAdapter do

  it_should_behave_like "a queue adapter", :resque, Taskinator::Queues::ResqueAdapter

  let(:adapter) { Taskinator::Queues::ResqueAdapter }
  let(:uuid) {  SecureRandom.uuid }

  subject { adapter.new() }

  describe "ProcessWorker" do
    it "enqueues processes" do
      worker = adapter::ProcessWorker
      subject.enqueue_process(double('process', :uuid => uuid, :queue => nil))

      expect(worker).to have_queued(uuid)
    end

    it "calls process worker" do
      expect_any_instance_of(Taskinator::ProcessWorker).to receive(:perform)
      adapter::ProcessWorker.perform(uuid)
    end
  end

  describe "TaskWorker" do
    it "enqueues tasks" do
      worker = adapter::TaskWorker
      subject.enqueue_task(double('task', :uuid => uuid, :queue => nil))

      expect(worker).to have_queued(uuid)
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

    it "calls job worker" do
      expect_any_instance_of(Taskinator::JobWorker).to receive(:perform)
      adapter::JobWorker.perform(uuid)
    end

    let(:definition) do
      Module.new() do
        extend Taskinator::Definition
      end
    end

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
