require 'spec_helper'

describe Taskinator::Definition do

  subject do
    Module.new do
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
      expect(subject).to respond_to(:create_process)
    end

    it "should not invoke the given block" do
      block = SpecSupport::Block.new
      expect(block).to_not receive(:call)
      subject.define_process(&block)
    end

    it "should raise ProcessAlreadyDefinedError error if already defined" do
      subject.define_process
      expect {
        subject.define_process
      }.to raise_error(Taskinator::Definition::ProcessAlreadyDefinedError)
    end

    it "should create a sequential process" do
      subject.define_process {}
      expect(subject.create_process).to be_a(Taskinator::Process::Sequential)
    end
  end

  describe "#define_sequential_process" do
    it "should define a #define_sequential_process method" do
      expect(subject).to respond_to(:define_sequential_process)
    end

    it "should not invoke the given block" do
      block = SpecSupport::Block.new
      expect(block).to_not receive(:call)
      subject.define_sequential_process(&block)
    end

    it "should raise ProcessAlreadyDefinedError error if already defined" do
      subject.define_sequential_process
      expect {
        subject.define_sequential_process
      }.to raise_error(Taskinator::Definition::ProcessAlreadyDefinedError)
    end

    it "should create a sequential process" do
      subject.define_sequential_process {}
      expect(subject.create_process).to be_a(Taskinator::Process::Sequential)
    end
  end

  describe "#define_concurrent_process" do
    it "should define a #define_concurrent_process method" do
      subject.define_concurrent_process
      expect(subject).to respond_to(:define_concurrent_process)
    end

    it "should not invoke the given block" do
      block = SpecSupport::Block.new
      expect(block).to_not receive(:call)
      subject.define_concurrent_process(&block)
    end

    it "should raise ProcessAlreadyDefinedError error if already defined" do
      subject.define_concurrent_process
      expect {
        subject.define_concurrent_process
      }.to raise_error(Taskinator::Definition::ProcessAlreadyDefinedError)
    end

    it "should create a concurrent process" do
      subject.define_concurrent_process {}
      expect(subject.create_process).to be_a(Taskinator::Process::Concurrent)
    end
  end

  describe "#create_process" do
    it "raises ProcessUndefinedError" do
      expect {
        subject.create_process
      }.to raise_error(Taskinator::Definition::ProcessUndefinedError)
    end

    it "returns a process" do
      block = SpecSupport::Block.new
      allow(block).to receive(:to_proc) {
        Proc.new {|*args| }
      }
      subject.define_process(&block)

      expect(subject.create_process).to be_a(Taskinator::Process)
    end

    it "invokes the given block in the context of a ProcessBuilder" do
      block = SpecSupport::Block.new
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

    context "is instrumented" do
      subject { MockDefinition.create }

      it "for create process" do
        instrumentation_block = SpecSupport::Block.new
        expect(instrumentation_block).to receive(:call)

        # temporary subscription
        ActiveSupport::Notifications.subscribed(instrumentation_block, /create_process/) do
          subject.create_process :foo
        end
      end

      it "for save process" do
        instrumentation_block = SpecSupport::Block.new
        expect(instrumentation_block).to receive(:call)

        # temporary subscription
        ActiveSupport::Notifications.subscribed(instrumentation_block, /save_process/) do
          subject.create_process :foo
        end
      end
    end
  end

  describe "#create_process_remotely" do
    it "raises ProcessUndefinedError" do
      expect {
        subject.create_process_remotely
      }.to raise_error(Taskinator::Definition::ProcessUndefinedError)
    end

    it "returns the process uuid" do
      block = SpecSupport::Block.new
      allow(block).to receive(:to_proc) {
        Proc.new {|*args| }
      }
      subject.define_process(&block)

      process = subject.create_process_remotely

      expect(process).to_not be_nil
      expect(process.uuid).to_not be_nil
    end

    it "enqueues" do
      block = SpecSupport::Block.new
      allow(block).to receive(:to_proc) {
        Proc.new {|*args| }
      }
      subject.define_process(&block)

      expect(Taskinator.queue).to receive(:enqueue_create_process)

      subject.create_process_remotely
    end

    describe "reloading" do
      it "returns false if not persisted yet" do
        block = SpecSupport::Block.new
        allow(block).to receive(:to_proc) {
          Proc.new {|*args| }
        }
        subject.define_process(&block)
        process = subject.create_process_remotely

        expect(process.reload).to eq(false)
      end

      it "returns true if persisted" do
        definition = MockDefinition.create
        process = definition.create_process_remotely(:foo)
        definition._create_process_(:foo, :uuid => process.uuid).save

        expect(process.reload).to eq(true)
      end
    end

  end

  describe "#queue" do
    it {
      expect(subject.queue).to be_nil
    }

    it {
      subject.queue = :foo
      expect(subject.queue).to eq(:foo)
    }
  end

end
