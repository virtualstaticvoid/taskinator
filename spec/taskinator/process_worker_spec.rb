require 'spec_helper'

describe Taskinator::ProcessWorker do

  def mock_process(paused=false, cancelled=false)
    double('process', :paused? => paused, :cancelled? => cancelled)
  end

  let(:uuid) { SecureRandom.uuid }

  subject { Taskinator::ProcessWorker.new(uuid) }

  it "should fetch the process" do
    process = mock_process
    expect(Taskinator::Process).to receive(:fetch).with(uuid) { process }
    allow(process).to receive(:start!)
    subject.perform
  end

  it "should start the process" do
    process = mock_process
    allow(Taskinator::Process).to receive(:fetch).with(uuid) { process }
    expect(process).to receive(:start!)
    subject.perform
  end

  it "should not start if paused" do
    process = mock_process(true, false)
    allow(Taskinator::Process).to receive(:fetch).with(uuid) { process }
    expect(process).to_not receive(:start!)
    subject.perform
  end

  it "should not start if cancelled" do
    process = mock_process(false, true)
    allow(Taskinator::Process).to receive(:fetch).with(uuid) { process }
    expect(process).to_not receive(:start!)
    subject.perform
  end

  it "should fail if process raises an error" do
    process = mock_process
    allow(Taskinator::Process).to receive(:fetch).with(uuid) { process }
    allow(process).to receive(:start!) { raise NotImplementedError }
    expect(process).to receive(:fail!).with(NotImplementedError)
    expect {
      subject.perform
    }.to raise_error(NotImplementedError)
  end

end
