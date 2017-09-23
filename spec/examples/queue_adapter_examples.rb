require 'spec_helper'

shared_examples_for "a queue adapter" do |adapter_name, adapter_type|

  subject { adapter_type.new({}) }
  let(:job) { double('job') }

  it "should instantiate adapter" do
    Taskinator.queue_adapter = adapter_name
    expect(Taskinator.queue.adapter).to be_a(adapter_type)
  end

  describe "#enqueue_create_process" do
    it { expect(subject).to respond_to(:enqueue_create_process) }

    it "should enqueue a create process" do
      expect(
        subject.enqueue_create_process(double('definition', :name => 'definition', :queue => nil), 'xx-xx-xx-xx', :foo => :bar)
      ).to_not be_nil
    end
  end

  describe "#enqueue_task" do
    it { expect(subject).to respond_to(:enqueue_task) }

    it "should enqueue a task" do
      expect(
        subject.enqueue_task(double('task', :uuid => 'xx-xx-xx-xx', :queue => nil))
      ).to_not be_nil
    end
  end

end
