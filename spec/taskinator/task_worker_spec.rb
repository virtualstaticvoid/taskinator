require 'spec_helper'

describe Taskinator::TaskWorker do

  def mock_task(paused=false, cancelled=false, can_complete=false)
    double('task', :paused? => paused, :cancelled? => cancelled, :can_complete? => can_complete)
  end

  let(:uuid) { SecureRandom.uuid }

  subject { Taskinator::TaskWorker.new(uuid) }

  it "should fetch the task" do
    task = mock_task
    expect(Taskinator::Task).to receive(:fetch).with(uuid) { task }
    allow(task).to receive(:start!)
    subject.perform
  end

  it "should start the task" do
    task = mock_task
    allow(Taskinator::Task).to receive(:fetch).with(uuid) { task }
    expect(task).to receive(:start!)
    subject.perform
  end

  it "should complete the task if can_complete? is true" do
    task = mock_task(false, false, true)
    allow(Taskinator::Task).to receive(:fetch).with(uuid) { task }
    allow(task).to receive(:start!)
    expect(task).to receive(:complete!)
    subject.perform
  end

  it "should not complete the task if can_complete? is false" do
    task = mock_task
    allow(Taskinator::Task).to receive(:fetch).with(uuid) { task }
    allow(task).to receive(:start!)
    expect(task).to_not receive(:complete!)
    subject.perform
  end

  it "should not start if paused" do
    task = mock_task(true, false)
    allow(Taskinator::Task).to receive(:fetch).with(uuid) { task }
    expect(task).to_not receive(:start!)
    subject.perform
  end

  it "should not start if cancelled" do
    task = mock_task(false, true)
    allow(Taskinator::Task).to receive(:fetch).with(uuid) { task }
    expect(task).to_not receive(:start!)
    subject.perform
  end

  it "should fail if task raises an error" do
    task = mock_task
    allow(Taskinator::Task).to receive(:fetch).with(uuid) { task }
    allow(task).to receive(:start!) { raise StandardError }
    expect(task).to receive(:fail!).with(StandardError)
    expect {
      subject.perform
    }.to raise_error(StandardError)
  end

end
