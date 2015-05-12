require 'spec_helper'

describe Taskinator::Definition do

  subject do
    Module.new() do
      extend Taskinator::Definition
    end
  end

  it "should respond to #define_process" do
    expect(subject).to respond_to(:define_process)
  end

  it "should have a #create_process method" do
    expect(subject).to respond_to(:create_process)
  end

  describe "#define_process" do
    it "should define a #create_process method" do
      subject.define_process
      expect(subject).to respond_to(:create_process)
    end

    it "should not invoke the given block" do
      block = SpecSupport::Block.new()
      expect(block).to_not receive(:call)
      subject.define_process(&block)
    end
  end

  describe "#create_process" do
    it "raises UndefinedProcessError" do
      expect {
        subject.create_process
      }.to raise_error(Taskinator::Definition::UndefinedProcessError)
    end

    it "returns a process" do
      block = SpecSupport::Block.new()
      allow(block).to receive(:to_proc) {
        Proc.new {|*args| }
      }
      subject.define_process(&block)

      expect(subject.create_process).to be_a(Taskinator::Process)
    end

    it "invokes the given block in the context of a ProcessBuilder" do
      block = SpecSupport::Block.new()
      expect(block).to receive(:call)

      subject.define_process do

        # make sure we get here!
        block.call

        # we should be in the context of the Builder
        # so methods such as concurrent, for_each and task
        # should be directly available
        raise RuntimeError unless self.respond_to?(:task)

      end

      # if an error is raised, then the context was incorrect
      expect {
        subject.create_process
      }.to_not raise_error
    end
  end

end
