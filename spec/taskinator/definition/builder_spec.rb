require 'spec_helper'

describe Taskinator::Definition::Builder do

  let(:definition) do
    Module.new() do
      extend Taskinator::Definition

      def iterator_method(*); end
      def task_method(*); end
    end
  end

  let(:process) {
    Class.new(Taskinator::Process).new('name', definition)
  }

  let(:args) { [:arg1, :arg2] }

  let(:block) { SpecSupport::Block.new() }

  let(:define_block) {
    the_block = block
    Proc.new {|*args| the_block.call }
  }

  subject { Taskinator::Definition::Builder.new(process, definition, args) }

  it "assign attributes" do
    expect(subject.process).to eq(process)
    expect(subject.definition).to eq(definition)
    expect(subject.args).to eq(args)
  end

  describe "#sequential" do
    it "invokes supplied block" do
      expect(block).to receive(:call)
      subject.sequential('name', &define_block)
    end

    it "creates a sequential process" do
      allow(block).to receive(:call)
      expect(Taskinator::Process).to receive(:define_sequential_process_for).with('name', definition, {}).and_call_original
      subject.sequential('name', &define_block)
    end

    it "fails if block isn't given" do
      expect {
        subject.sequential('name')
      }.to raise_error(ArgumentError)
    end
  end

  describe "#concurrent" do
    it "invokes supplied block" do
      expect(block).to receive(:call)
      subject.concurrent('name', &define_block)
    end

    it "creates a concurrent process" do
      allow(block).to receive(:call)
      expect(Taskinator::Process).to receive(:define_concurrent_process_for).with('name', definition, Taskinator::CompleteOn::First, {}).and_call_original
      subject.concurrent('name', Taskinator::CompleteOn::First, &define_block)
    end

    it "fails if block isn't given" do
      expect {
        subject.concurrent('name')
      }.to raise_error(ArgumentError)
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

      expect(executor).to receive(:iterator_method) do |*args, &block|
        3.times(&block)
      end

      expect(block).to receive(:call).exactly(3).times

      subject.for_each('name', :iterator_method, &define_block)
    end

    it "fails if iterator method is nil" do
      expect {
        subject.for_each('name', nil, &define_block)
      }.to raise_error(ArgumentError)
    end

    it "fails if iterator method is not defined" do
      expect {
        subject.for_each('name', :undefined_iterator, &define_block)
      }.to raise_error(NoMethodError)
    end

    it "fails if block isn't given" do
      expect {
        subject.for_each('name', nil)
      }.to raise_error(ArgumentError)
    end
  end

  describe "#task" do
    it "creates a task" do
      expect(Taskinator::Task).to receive(:define_step_task).with('name', process, :task_method, args, {})
      subject.task('name', :task_method)
    end

    it "fails if task method is nil" do
      expect {
        subject.task('name', nil)
      }.to raise_error(ArgumentError)
    end

    it "fails if task method is not defined" do
      expect {
        subject.task('name', :undefined_method)
      }.to raise_error(NoMethodError)
    end
  end

  describe "#sub_process" do
    let(:sub_definition) do
      Module.new() do
        extend Taskinator::Definition

        define_process {}
      end
    end

    it "creates a sub process" do
      expect(sub_definition).to receive(:create_process).with(*args).and_call_original
      subject.sub_process('name', sub_definition)
    end

    it "creates a sub process task" do
      sub_process = sub_definition.create_process(:argX, :argY)
      allow(sub_definition).to receive(:create_process) { sub_process }
      expect(Taskinator::Task).to receive(:define_sub_process_task).with('name', process, sub_process, {})
      subject.sub_process('name', sub_definition)
    end
  end

end
