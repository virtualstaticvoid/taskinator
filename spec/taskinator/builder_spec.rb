require 'spec_helper'

describe Taskinator::Builder do

  let(:definition) do
    Module.new do
      extend Taskinator::Definition

      def iterator_method(*args)
        yield *args
      end

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

  subject { Taskinator::Builder.new(process, definition, *[*args, builder_options]) }

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

    describe "scopes" do
      it "base" do
        expect(block).to receive(:call)
        blk = define_block

        definition.define_process :a, :b do
          option?(:option1, &blk)
        end

        definition.create_process(*args, builder_options)
      end

      it "sequential" do
        expect(block).to receive(:call)
        blk = define_block

        definition.define_process :a, :b do
          sequential do
            option?(:option1, &blk)
          end
        end

        definition.create_process(*args, builder_options)
      end

      it "concurrent" do
        expect(block).to receive(:call)
        blk = define_block

        definition.define_process :a, :b do
          concurrent do
            option?(:option1, &blk)
          end
        end

        definition.create_process(*args, builder_options)
      end

      it "for_each" do
        expect(block).to receive(:call)
        blk = define_block

        definition.define_process :a, :b do
          for_each :iterator_method do
            option?(:option1, &blk)
          end
        end

        definition.create_process(*args, builder_options)
      end

      it "nested" do
        expect(block).to receive(:call)
        blk = define_block

        definition.define_process :a, :b do
          concurrent do
            sequential do
              for_each :iterator_method do
                option?(:option1, &blk)
              end
            end
          end
        end

        definition.create_process(*args, builder_options)
      end

      it "sub-process" do
        expect(block).to receive(:call).exactly(4).times
        blk = define_block

        sub_definition = Module.new do
          extend Taskinator::Definition

          define_process do
            option?(:option1, &blk) #1

            sequential do
              option?(:option1, &blk) #2
            end

            concurrent do
              option?(:option1, &blk) #3
            end

            for_each :iterator_method do
              option?(:option1, &blk) #4
            end
          end

          def iterator_method(*args)
            yield *args
          end
        end

        definition.define_process :a, :b do
          sub_process sub_definition
        end

        definition.create_process(*args, builder_options)
      end
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

    it "adds task to process" do
      expect {
        subject.task(:task_method)
      }.to change { process.tasks.count }.by(1)
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

    it "adds job to process" do
      expect {
        subject.task(:task_method)
      }.to change { process.tasks.count }.by(1)
    end
  end

  describe "#before_started" do
    it "creates a task" do
      expect(Taskinator::Task).to receive(:define_hook_task).with(process, :task_method, args, builder_options)
      subject.before_started(:task_method)
    end

    it "fails if task method is nil" do
      expect {
        subject.before_started(nil)
      }.to raise_error(ArgumentError)
    end

    it "fails if task method is not defined" do
      expect {
        subject.before_started(:undefined)
      }.to raise_error(NoMethodError)
    end

    it "includes options" do
      expect(Taskinator::Task).to receive(:define_hook_task).with(process, :task_method, args, builder_options.merge(options))
      subject.before_started(:task_method, options)
    end

    it "adds task to process" do
      expect {
        subject.before_started(:task_method)
      }.to change { process.before_started_tasks.count }.by(1)
    end
  end

  describe "#after_completed" do
    it "creates a task" do
      expect(Taskinator::Task).to receive(:define_hook_task).with(process, :task_method, args, builder_options)
      subject.after_completed(:task_method)
    end

    it "fails if task method is nil" do
      expect {
        subject.after_completed(nil)
      }.to raise_error(ArgumentError)
    end

    it "fails if task method is not defined" do
      expect {
        subject.after_completed(:undefined)
      }.to raise_error(NoMethodError)
    end

    it "includes options" do
      expect(Taskinator::Task).to receive(:define_hook_task).with(process, :task_method, args, builder_options.merge(options))
      subject.after_completed(:task_method, options)
    end

    it "adds task to process" do
      expect {
        subject.after_completed(:task_method)
      }.to change { process.after_completed_tasks.count }.by(1)
    end
  end

  describe "#after_failed" do
    it "creates a task" do
      expect(Taskinator::Task).to receive(:define_hook_task).with(process, :task_method, args, builder_options)
      subject.after_failed(:task_method)
    end

    it "fails if task method is nil" do
      expect {
        subject.after_failed(nil)
      }.to raise_error(ArgumentError)
    end

    it "fails if method is not defined" do
      expect {
        subject.after_failed(:undefined)
      }.to raise_error(NoMethodError)
    end

    it "includes options" do
      expect(Taskinator::Task).to receive(:define_hook_task).with(process, :task_method, args, builder_options.merge(options))
      subject.after_failed(:task_method, options)
    end

    it "adds task to process" do
      expect {
        subject.after_failed(:task_method)
      }.to change { process.after_failed_tasks.count }.by(1)
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
      expect {
        subject.sequential(options, &block)
      }.to change { process.tasks.count }.by(1)
    end

    it "ignores sub-processes without tasks" do
      allow(block).to receive(:call)
      expect {
        subject.sequential(options, &define_block)
      }.to_not change { process.tasks.count }
    end
  end

end
