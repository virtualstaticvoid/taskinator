require 'spec_helper'

describe Taskinator::Executor do

  let(:definition) do
    Module.new do
      def method; end
    end
  end

  let(:task) { double('task') }
  subject { Taskinator::Executor.new(definition, task) }

  describe "helpers" do
    it "#process_uuid" do
      expect(task).to receive(:process_uuid)
      subject.process_uuid
    end

    it "#uuid" do
      expect(task).to receive(:uuid)
      subject.uuid
    end

    it "#options" do
      expect(task).to receive(:options)
      subject.options
    end
  end

  it "should mixin definition" do
    expect(subject).to be_a(definition)
  end

  it "should mixin definition for the instance only" do
    expect(Taskinator::Executor).to_not be_a(definition)
  end

  it "should assign definition" do
    expect(subject.definition).to eq(definition)
  end

  it "should contain definition methods" do
    expect(subject).to respond_to(:method)
  end

end
