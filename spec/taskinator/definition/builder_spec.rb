require 'spec_helper'

describe Taskinator::Definition::Builder do

  let(:definition) do
    Module.new do
      extend Taskinator::Definition

      def iterator_method(*); end
      def task_method(*); end
    end
  end

  let(:process) {
    Class.new(Taskinator::Process).new(definition)
  }

  let(:args) { [:arg1, :arg2] }
  let(:builder_options) { {:option1 => 1, :another => false} }
  let(:options) { { :bar => :baz } }

  let(:block) { SpecSupport::Block.new }

  let(:define_block) {
    the_block = block
    Proc.new {|*args| the_block.call }
  }

  subject { Taskinator::Definition::Builder.new(process, definition, *[*args, builder_options]) }

  it "assign attributes" do
    expect(subject.process).to eq(process)
    expect(subject.definition).to eq(definition)
    expect(subject.args).to eq(args)
    expect(subject.builder_options).to eq(builder_options)
  end

  describe "#option?" do
    it "invokes supplied block for 'option1' option" do
      expect(block).to receive(:call)
      subject.option?(:option1, &define_block)
    end

    it "does not invoke supplied block for 'another' option" do
      expect(block).to_not receive(:call)
      subject.option?(:another, &define_block)
    end

    it "does not invoke supplied block for an unspecified option" do
      expect(block).to_not receive(:call)
      subject.option?(:unspecified, &define_block)
    end
  end

  describe "#sequential" do
    it "invokes supplied block" do
      expect(block).to receive(:call)
      subject.sequential(&define_block)
    end

    it "creates a sequential process" do
      allow(block).to receive(:call)
      expect(Taskinator::Process).to receive(:define_sequential_process_for).with(definition, {}).and_call_original
      subject.sequential(&define_block)
    end

    it "fails if block isn't given" do
      expect {
        subject.sequential
      }.to raise_error(ArgumentError)
    end

    it "includes options" do
      allow(block).to receive(:call)
      expect(Taskinator::Process).to receive(:define_sequential_process_for).with(definition, options).and_call_original
      subject.sequential(options, &define_block)
    end

    it "adds sub-process task" do
      block = Proc.new {|p|
        p.task :task_method
      }
      expect(process.tasks).to be_empty
      subject.sequential(options, &block)
      expect(process.tasks).to_not be_empty
    end

    it "ignores sub-processes without tasks" do
      allow(block).to receive(:call)
      expect(process.tasks).to be_empty
      subject.sequential(options, &define_block)
      expect(process.tasks).to be_empty
    end
  end

  describe "#concurrent" do
    it "invokes supplied block" do
      expect(block).to receive(:call)
      subject.concurrent(&define_block)
    end

    it "creates a concurrent process" do
      allow(block).to receive(:call)
      expect(Taskinator::Process).to receive(:define_concurrent_process_for).with(definition, Taskinator::CompleteOn::First, {}).and_call_original
      subject.concurrent(Taskinator::CompleteOn::First, &define_block)
    end

    it "fails if block isn't given" do
      expect {
        subject.concurrent
      }.to raise_error(ArgumentError)
    end

    it "includes options" do
      allow(block).to receive(:call)
      expect(Taskinator::Process).to receive(:define_concurrent_process_for).with(definition, Taskinator::CompleteOn::First, options).and_call_original
      subject.concurrent(Taskinator::CompleteOn::First, options, &define_block)
    end

    it "adds sub-process task" do
      block = Proc.new {|p|
        p.task :task_method
      }
      expect(process.tasks).to be_empty
      subject.sequential(options, &block)
      expect(process.tasks).to_not be_empty
    end

    it "ignores sub-processes without tasks" do
      allow(block).to receive(:call)
      expect(process.tasks).to be_empty
      subject.sequential(options, &define_block)
      expect(process.tasks).to be_empty
    end
  end

  describe "#for_each" do
    it "creates tasks for each returned item" do
      # the definition is mixed into the eigen class of Executor

      # HACK: replace the internal executor instance
      executor = Taskinator::Executor.new(definition)
      subject.instance_eval do
        @executor = executor
      end

      expect(executor).to receive(:iterator_method).with(*args) do |*a, &block|
        3.times(&block)
      end

      expect(block).to receive(:call).exactly(3).times

      subject.for_each(:iterator_method, &define_block)
    end

    it "fails if iterator method is nil" do
      expect {
        subject.for_each(nil, &define_block)
      }.to raise_error(ArgumentError)
    end

    it "fails if iterator method is not defined" do
      expect {
        subject.for_each(:undefined_iterator, &define_block)
      }.to raise_error(NoMethodError)
    end

    it "fails if block isn't given" do
      expect {
        subject.for_each(nil)
      }.to raise_error(ArgumentError)
    end

    it "calls the iterator method, adding specified options" do
      executor = Taskinator::Executor.new(definition)

      subject.instance_eval do
        @executor = executor
      end

      expect(executor).to receive(:iterator_method).with(*[*args, :sub_option => 1]) do |*a, &block|
        3.times(&block)
      end

      expect(block).to receive(:call).exactly(3).times

      subject.for_each(:iterator_method, :sub_option => 1, &define_block)
    end
  end

  # NOTE: #transform is an alias for #for_each

  describe "#task" do
    it "creates a task" do
      expect(Taskinator::Task).to receive(:define_step_task).with(process, :task_method, args, builder_options)
      subject.task(:task_method)
    end

    it "fails if task method is nil" do
      expect {
        subject.task(nil)
      }.to raise_error(ArgumentError)
    end

    it "fails if task method is not defined" do
      expect {
        subject.task(:undefined)
      }.to raise_error(NoMethodError)
    end

    it "includes options" do
      expect(Taskinator::Task).to receive(:define_step_task).with(process, :task_method, args, builder_options.merge(options))
      subject.task(:task_method, options)
    end
  end

  describe "#job" do
    it "creates a job" do
      job = double('job', :perform => true)
      expect(Taskinator::Task).to receive(:define_job_task).with(process, job, args, builder_options)
      subject.job(job)
    end

    it "fails if job module is nil" do
      expect {
        subject.job(nil)
      }.to raise_error(ArgumentError)
    end

    # ok, fuzzy logic to determine what is ia job here!
    it "fails if job module is not a job" do
      expect {
        subject.job(double('job', :methods => [], :instance_methods => []))
      }.to raise_error(ArgumentError)
    end

    it "includes options" do
      job = double('job', :perform => true)
      expect(Taskinator::Task).to receive(:define_job_task).with(process, job, args, builder_options.merge(options))
      subject.job(job, options)
    end
  end

  describe "#sub_process" do
    let(:sub_definition) do
      Module.new do
        extend Taskinator::Definition

        define_process :some_arg1, :some_arg2, :some_arg3 do
        end
      end
    end

    it "creates a sub process" do
      expect(sub_definition).to receive(:create_sub_process).with(*args, builder_options).and_call_original
      subject.sub_process(sub_definition)
    end

    it "creates a sub process task" do
      sub_process = sub_definition.create_process(:argX, :argY, :argZ)
      allow(sub_definition).to receive(:create_sub_process) { sub_process }
      expect(Taskinator::Task).to receive(:define_sub_process_task).with(process, sub_process, builder_options)
      subject.sub_process(sub_definition)
    end

    it "includes options" do
      expect(sub_definition).to receive(:create_sub_process).with(*args, builder_options.merge(options)).and_call_original
      subject.sub_process(sub_definition, options)
    end

    it "adds sub-process task" do
      block = Proc.new {|p|
        p.task :task_method
      }
      expect(process.tasks).to be_empty
      subject.sequential(options, &block)
      expect(process.tasks).to_not be_empty
    end

    it "ignores sub-processes without tasks" do
      allow(block).to receive(:call)
      expect(process.tasks).to be_empty
      subject.sequential(options, &define_block)
      expect(process.tasks).to be_empty
    end
  end

end
