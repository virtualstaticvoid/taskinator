require 'spec_helper'

describe Taskinator::JobWorker do

  def mock_job(paused=false, cancelled=false)
    double('job', :paused? => paused, :cancelled? => cancelled)
  end

  let(:uuid) { SecureRandom.uuid }

  subject { Taskinator::JobWorker.new(uuid) }

  it "should fetch the job" do
    job = mock_job
    expect(Taskinator::Task).to receive(:fetch).with(uuid) { job }
    allow(job).to receive(:start!)
    allow(job).to receive(:perform)
    allow(job).to receive(:complete!)
    subject.perform
  end

  it "should start the job" do
    job = mock_job
    allow(Taskinator::Task).to receive(:fetch).with(uuid) { job }
    expect(job).to receive(:start!) { }
    allow(job).to receive(:perform)
    allow(job).to receive(:complete!)
    subject.perform
  end

  it "should perform the job" do
    job = mock_job(false, false)
    allow(Taskinator::Task).to receive(:fetch).with(uuid) { job }
    allow(job).to receive(:start!)
    expect(job).to receive(:perform)
    subject.perform
  end

  it "should not start if paused" do
    job = mock_job(true, false)
    allow(Taskinator::Task).to receive(:fetch).with(uuid) { job }
    expect(job).to_not receive(:start!)
    subject.perform
  end

  it "should not start if cancelled" do
    job = mock_job(false, true)
    allow(Taskinator::Task).to receive(:fetch).with(uuid) { job }
    expect(job).to_not receive(:start!)
    subject.perform
  end

  it "should fail if job raises an error" do
    job = mock_job
    allow(Taskinator::Task).to receive(:fetch).with(uuid) { job }
    allow(job).to receive(:start!) { raise StandardError }
    expect {
      subject.perform
    }.to raise_error(StandardError)
  end

end
