require 'spec_helper'

shared_examples_for "a queue adapter" do |adapter_name, adapter_type|

  subject { adapter_type.new({}) }
  let(:job) { double('job') }

  it "should instantiate adapter" do
    Taskinator.queue_adapter = adapter_name
    expect(Taskinator.queue.adapter).to be_a(adapter_type)
  end

  describe "#enqueue_process" do
    it { expect(subject).to respond_to(:enqueue_process) }

    it "should enqueue a process" do
      expect {
        subject.enqueue_process(double('process', :uuid => 'xx-xx-xx-xx', :queue => nil))
      }.to_not raise_error
    end
  end

  describe "#enqueue_task" do
    it { expect(subject).to respond_to(:enqueue_task) }

    it "should enqueue a task" do
      expect {
        subject.enqueue_task(double('task', :uuid => 'xx-xx-xx-xx', :queue => nil))
      }.to_not raise_error
    end
  end

  describe "#enqueue_job" do
    it { expect(subject).to respond_to(:enqueue_job) }

    it "should enqueue a job" do
      expect {
        subject.enqueue_job(double('job', :uuid => 'xx-xx-xx-xx', :job => job, :queue => nil))
      }.to_not raise_error
    end
  end

end
