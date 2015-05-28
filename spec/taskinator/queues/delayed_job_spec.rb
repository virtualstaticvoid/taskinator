require 'spec_helper'

describe Taskinator::Queues::DelayedJobAdapter do

  it_should_behave_like "a queue adapter", :delayed_job, Taskinator::Queues::DelayedJobAdapter

  let(:adapter) { Taskinator::Queues::DelayedJobAdapter }
  let(:uuid) {  SecureRandom.uuid }

  subject { adapter.new() }

  describe "ProcessWorker" do
    it "enqueues processes" do
      worker = adapter::ProcessWorker
      expect {
        subject.enqueue_process(double('process', :uuid => uuid, :queue => nil))
      }.to change(Delayed::Job.queue, :size).by(1)
    end

    it "calls process worker" do
      expect_any_instance_of(Taskinator::ProcessWorker).to receive(:perform)
      adapter::ProcessWorker.new(uuid).perform
    end
  end

  describe "TaskWorker" do
    it "enqueues tasks" do
      worker = adapter::TaskWorker
      expect {
        subject.enqueue_process(double('task', :uuid => uuid, :queue => nil))
      }.to change(Delayed::Job.queue, :size).by(1)
    end

    it "calls task worker" do
      expect_any_instance_of(Taskinator::TaskWorker).to receive(:perform)
      adapter::TaskWorker.new(uuid).perform
    end
  end

  describe "JobWorker" do
    it "enqueues jobs" do
      worker = adapter::JobWorker

      job = double('job')
      job_task = double('job_task', :uuid => uuid, :job => job, :queue => nil)

      expect {
        subject.enqueue_job(job_task)
      }.to change(Delayed::Job.queue, :size).by(1)
    end

    it "calls job worker" do
      expect_any_instance_of(Taskinator::JobWorker).to receive(:perform)
      adapter::JobWorker.new(uuid).perform
    end

    let(:definition) do
      Module.new() do
        extend Taskinator::Definition
      end
    end

    it "performs invocation on job" do
      args = {:a => 1}
      job = double('job')
      expect(job).to receive(:perform)

      job_class = double('job_class', :instance_methods => [:perform])
      allow(job_class).to receive(:new).with(*args) { job }

      process = Taskinator::Process::Sequential.new(definition)
      job_task = Taskinator::Task.define_job_task(process, job_class, args)

      allow(Taskinator::Task).to receive(:fetch).with(uuid) { job_task }

      adapter::JobWorker.new(uuid).perform
    end
  end
end
