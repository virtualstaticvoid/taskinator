require 'spec_helper'

describe Taskinator::Task do

  let(:definition) { TestDefinition }

  let(:process) do
    Class.new(Taskinator::Process) do
      include ProcessMethods
    end.new(definition)
  end

  describe "Base" do

    subject do
      Class.new(Taskinator::Task) do
        include TaskMethods
      end.new(process)
    end

    describe "#initialize" do
      it { expect(subject.process).to_not be_nil }
      it { expect(subject.process).to eq(process) }
      it { expect(subject.uuid).to_not be_nil }
      it { expect(subject.options).to_not be_nil }
    end

    describe "#<==>" do
      it { expect(subject).to be_a(::Comparable)  }
      it {
        uuid = subject.uuid
        expect(subject == double('test', :uuid => uuid)).to be
      }

      it {
        expect(subject == double('test', :uuid => 'xxx')).to_not be
      }
    end

    describe "#to_s" do
      it { expect(subject.to_s).to match(/#{subject.uuid}/) }
    end

    describe "#queue" do
      it {
        expect(subject.queue).to be_nil
      }

      it {
        task = Class.new(Taskinator::Task).new(process, :queue => :foo)
        expect(task.queue).to eq(:foo)
      }
    end

    describe "#current_state" do
      it { expect(subject).to be_a(Taskinator::Workflow)  }
      it { expect(subject.current_state).to_not be_nil }
      it { expect(subject.current_state).to eq(:initial) }
    end

    describe "workflow" do
      describe "#enqueue!" do
        it { expect(subject).to respond_to(:enqueue!) }
        it {
          expect(subject).to receive(:enqueue)
          subject.enqueue!
        }
        it {
          subject.enqueue!
          expect(subject.current_state).to eq(:enqueued)
        }
      end

      describe "#start!" do
        it { expect(subject).to respond_to(:start!) }
        it {
          expect(subject).to receive(:start)
          subject.start!
        }
        it {
          subject.start!
          expect(subject.current_state).to eq(:processing)
        }
      end

      describe "#complete!" do
        it { expect(subject).to respond_to(:complete!) }
        it {
          expect(subject).to receive(:complete)
          subject.start!
          subject.complete!
          expect(subject.current_state).to eq(:completed)
        }
      end

      describe "#fail!" do
        it { expect(subject).to respond_to(:fail!) }
        it {
          error = StandardError.new
          expect(subject).to receive(:fail).with(error)
          expect(process).to receive(:task_failed).with(subject, error)
          subject.start!
          subject.fail!(error)
        }
        it {
          subject.start!
          subject.fail!(StandardError.new)
          expect(subject.current_state).to eq(:failed)
        }
      end

      describe "#paused?" do
        it { expect(subject.paused?).to_not be }
        it {
          process.start!
          process.pause!
          expect(subject.paused?).to eq(true)
        }
      end

      describe "#cancelled?" do
        it { expect(subject.cancelled?).to_not be }
        it {
          process.cancel!
          expect(subject.cancelled?).to be
        }
      end
    end

    describe "#next" do
      it { expect(subject).to respond_to(:next) }
      it { expect(subject).to respond_to(:next=) }
    end

    describe "#accept" do
      it { expect(subject).to be_a(Taskinator::Persistence) }

      it {
        expect(subject).to receive(:accept)
        subject.save
      }

      it {
        visitor = double('visitor')
        expect(visitor).to receive(:visit_attribute).with(:uuid)
        expect(visitor).to receive(:visit_process_reference).with(:process)
        expect(visitor).to receive(:visit_task_reference).with(:next)
        expect(visitor).to receive(:visit_args).with(:options)
        expect(visitor).to receive(:visit_attribute).with(:queue)
        expect(visitor).to receive(:visit_attribute_time).with(:created_at)
        expect(visitor).to receive(:visit_attribute_time).with(:updated_at)

        subject.accept(visitor)
      }
    end

    describe "#tasks_count" do
      it {
        process_uuid = SecureRandom.hex
        allow(subject).to receive(:process_uuid) { process_uuid }
        expect(subject.tasks_count).to eq(0)
      }
    end
  end

  describe Taskinator::Task::Step do

    subject { Taskinator::Task.define_step_task(process, :do_task, {:a => 1, :b => 2}) }

    it_should_behave_like "a task", Taskinator::Task::Step

    describe ".define_step_task" do
      it "sets the queue to use" do
        task = Taskinator::Task.define_step_task(process, :do_task, {:a => 1, :b => 2}, :queue => :foo)
        expect(task.queue).to eq(:foo)
      end
    end

    describe "#executor" do
      it { expect(subject.executor).to_not be_nil }
      it { expect(subject.executor).to be_a(definition) }

      it "handles failure" do
        error = StandardError.new
        allow(subject.executor).to receive(subject.method).with(*subject.args).and_raise(error)
        expect(subject).to receive(:fail!).with(error)
        expect {
          subject.start!
        }.to raise_error(error)
      end
    end

    describe "#enqueue!" do
      it {
        expect {
          subject.enqueue!
        }.to change { Taskinator.queue.tasks.length }.by(1)
      }

      it "is instrumented" do
        allow(subject.executor).to receive(subject.method).with(*subject.args)

        instrumentation_block = SpecSupport::Block.new

        expect(instrumentation_block).to receive(:call) do |*args|
          expect(args.first).to eq('taskinator.task.enqueued')
        end

        TestInstrumenter.subscribe(instrumentation_block, /taskinator.task/) do
          subject.enqueue!
        end
      end
    end

    describe "#start!" do
      before do
        allow(process).to receive(:task_completed).with(subject)
      end

      it "invokes executor" do
        expect(subject.executor).to receive(subject.method).with(*subject.args)
        subject.start!
      end

      it "provides execution context" do
        executor = Taskinator::Executor.new(definition, subject)

        method = subject.method

        executor.singleton_class.class_eval do
          define_method method do |*args|
            # this method executes in the scope of the executor
            # store the context in an instance variable
            @exec_context = self
          end
        end

        # replace the internal executor instance for the task
        # with this one, so we can hook into the methods
        subject.instance_eval { @executor = executor }

        # task start will invoke the method on the executor
        subject.start!

        # extract the instance variable
        exec_context = executor.instance_eval { @exec_context }

        expect(exec_context).to eq(executor)
        expect(exec_context.uuid).to eq(subject.uuid)
        expect(exec_context.options).to eq(subject.options)
      end

      it "is instrumented" do
        instrumentation_block = SpecSupport::Block.new

        expect(instrumentation_block).to receive(:call) do |*args|
          expect(args.first).to eq('taskinator.task.processing')
        end

        expect(instrumentation_block).to receive(:call) do |*args|
          expect(args.first).to eq('taskinator.task.completed')
        end

        TestInstrumenter.subscribe(instrumentation_block) do
          subject.start!
        end
      end
    end

    describe "#complete" do
      it "notifies parent process" do
        expect(process).to receive(:task_completed).with(subject)

        subject.complete!
      end

      it "is instrumented" do
        allow(process).to receive(:task_completed).with(subject)

        instrumentation_block = SpecSupport::Block.new

        expect(instrumentation_block).to receive(:call) do |*args|
          expect(args.first).to eq('taskinator.task.completed')
        end

        TestInstrumenter.subscribe(instrumentation_block, /taskinator.task/) do
          subject.complete!
        end
      end
    end

    describe "#accept" do
      it {
        expect(subject).to receive(:accept)
        subject.save
      }

      it {
        visitor = double('visitor')
        expect(visitor).to receive(:visit_type).with(:definition)
        expect(visitor).to receive(:visit_attribute).with(:uuid)
        expect(visitor).to receive(:visit_process_reference).with(:process)
        expect(visitor).to receive(:visit_task_reference).with(:next)
        expect(visitor).to receive(:visit_args).with(:options)
        expect(visitor).to receive(:visit_attribute).with(:method)
        expect(visitor).to receive(:visit_args).with(:args)
        expect(visitor).to receive(:visit_attribute).with(:queue)
        expect(visitor).to receive(:visit_attribute_time).with(:created_at)
        expect(visitor).to receive(:visit_attribute_time).with(:updated_at)

        subject.accept(visitor)
      }
    end

    describe "#inspect" do
      it { expect(subject.inspect).to_not be_nil }
    end
  end

  describe Taskinator::Task::Job do

    module TestJob
      def self.perform(*args)
      end
    end

    class TestJobClass
      def perform(*args)
      end
    end

    module TestJobModule
      def self.perform(*args)
      end
    end

    class TestJobClassNoArgs
      def perform
      end
    end

    module TestJobModuleNoArgs
      def self.perform
      end
    end

    subject { Taskinator::Task.define_job_task(process, TestJob, [1, {:a => 1, :b => 2}]) }

    it_should_behave_like "a task", Taskinator::Task::Job

    describe ".define_job_task" do
      it "sets the queue to use" do
        task = Taskinator::Task.define_job_task(process, TestJob, [1, {:a => 1, :b => 2}], :queue => :foo)
        expect(task.queue).to eq(:foo)
      end
    end

    describe "#enqueue!" do
      it {
        expect {
          subject.enqueue!
        }.to change { Taskinator.queue.tasks.length }.by(1)
      }

      it "is instrumented" do
        instrumentation_block = SpecSupport::Block.new

        expect(instrumentation_block).to receive(:call) do |*args|
          expect(args.first).to eq('taskinator.task.enqueued')
        end

        TestInstrumenter.subscribe(instrumentation_block, /taskinator.task/) do
          subject.enqueue!
        end
      end
    end

    describe "#start" do
      it {
        task = Taskinator::Task.define_job_task(process, TestJobClass, [1, {:a => 1, :b => 2}])
        expect(process).to receive(:task_completed).with(task)
        expect_any_instance_of(TestJobClass).to receive(:perform).with(1, {:a => 1, :b => 2})
        task.start!
      }

      it {
        task = Taskinator::Task.define_job_task(process, TestJobModule, [2, {:a => 1, :b => 2}])
        expect(process).to receive(:task_completed).with(task)
        expect(TestJobModule).to receive(:perform).with(2, {:a => 1, :b => 2})
        task.start!
      }

      it {
        task = Taskinator::Task.define_job_task(process, TestJobClassNoArgs, nil)
        expect(process).to receive(:task_completed).with(task)
        expect_any_instance_of(TestJobClassNoArgs).to receive(:perform).and_call_original
        task.start!
      }

      it {
        task = Taskinator::Task.define_job_task(process, TestJobModuleNoArgs, nil)
        expect(process).to receive(:task_completed).with(task)
        expect(TestJobModuleNoArgs).to receive(:perform).and_call_original
        task.start!
      }

      it "is instrumented" do
        allow(process).to receive(:task_completed).with(subject)

        allow(TestJob).to receive(:perform).with(1, {:a => 1, :b => 2})

        instrumentation_block = SpecSupport::Block.new

        expect(instrumentation_block).to receive(:call) do |*args|
          expect(args.first).to eq('taskinator.task.processing')
        end

        # special case, since when the method returns, the task is considered to be complete
        expect(instrumentation_block).to receive(:call) do |*args|
          expect(args.first).to eq('taskinator.task.completed')
        end

        TestInstrumenter.subscribe(instrumentation_block, /taskinator.task/) do
          subject.start!
        end
      end
    end

    describe "#complete" do
      it "notifies parent process" do
        expect(process).to receive(:task_completed).with(subject)

        subject.complete!
      end

      it "is instrumented" do
        allow(process).to receive(:task_completed).with(subject)

        instrumentation_block = SpecSupport::Block.new

        expect(instrumentation_block).to receive(:call) do |*args|
          expect(args.first).to eq('taskinator.task.completed')
        end

        TestInstrumenter.subscribe(instrumentation_block, /taskinator.task/) do
          subject.complete!
        end
      end
    end

    describe "#accept" do
      it {
        expect(subject).to receive(:accept)
        subject.save
      }

      it {
        visitor = double('visitor')
        expect(visitor).to receive(:visit_type).with(:definition)
        expect(visitor).to receive(:visit_attribute).with(:uuid)
        expect(visitor).to receive(:visit_process_reference).with(:process)
        expect(visitor).to receive(:visit_task_reference).with(:next)
        expect(visitor).to receive(:visit_args).with(:options)
        expect(visitor).to receive(:visit_type).with(:job)
        expect(visitor).to receive(:visit_args).with(:args)
        expect(visitor).to receive(:visit_attribute).with(:queue)
        expect(visitor).to receive(:visit_attribute_time).with(:created_at)
        expect(visitor).to receive(:visit_attribute_time).with(:updated_at)

        subject.accept(visitor)
      }
    end

    describe "#inspect" do
      it { expect(subject.inspect).to_not be_nil }
    end
  end

  describe Taskinator::Task::SubProcess do

    let(:sub_process) do
      Class.new(Taskinator::Process) do
        include ProcessMethods
      end.new(definition)
    end

    subject { Taskinator::Task.define_sub_process_task(process, sub_process) }

    it_should_behave_like "a task", Taskinator::Task::SubProcess

    describe ".define_sub_process_task" do
      it "sets the queue to use" do
        task = Taskinator::Task.define_sub_process_task(process, sub_process, :queue => :foo)
        expect(task.queue).to eq(:foo)
      end
    end

    describe "#enqueue!" do
      context "without tasks" do
        it {
          expect {
            subject.enqueue!
          }.to change { Taskinator.queue.tasks.length }.by(0)
        }
      end

      it "delegates to sub process" do
        expect(sub_process).to receive(:enqueue!)
        subject.enqueue!
      end

      it "is instrumented" do
        instrumentation_block = SpecSupport::Block.new

        expect(instrumentation_block).to receive(:call) do |*args|
          expect(args.first).to eq('taskinator.task.enqueued')
        end

        TestInstrumenter.subscribe(instrumentation_block, /taskinator.task/) do
          subject.enqueue!
        end
      end
    end

    describe "#start!" do
      it "delegates to sub process" do
        expect(sub_process).to receive(:start)
        subject.start!
      end

      it "handles failure" do
        error = StandardError.new
        allow(sub_process).to receive(:start!).and_raise(error)
        expect(subject).to receive(:fail!).with(error)
        expect {
          subject.start!
        }.to raise_error(error)
      end

      it "is instrumented" do
        instrumentation_block = SpecSupport::Block.new

        expect(instrumentation_block).to receive(:call) do |*args|
          expect(args.first).to eq('taskinator.task.processing')
        end

        TestInstrumenter.subscribe(instrumentation_block, /taskinator.task/) do
          subject.start!
        end
      end
    end

    describe "#complete" do
      it "notifies parent process" do
        expect(process).to receive(:task_completed).with(subject)

        subject.complete!
      end

      it "is instrumented" do
        allow(process).to receive(:task_completed).with(subject)

        instrumentation_block = SpecSupport::Block.new

        expect(instrumentation_block).to receive(:call) do |*args|
          expect(args.first).to eq('taskinator.task.completed')
        end

        TestInstrumenter.subscribe(instrumentation_block, /taskinator.task/) do
          subject.complete!
        end
      end
    end

    describe "#accept" do
      it {
        expect(subject).to receive(:accept)
        subject.save
      }

      it {
        visitor = double('visitor')
        expect(visitor).to receive(:visit_attribute).with(:uuid)
        expect(visitor).to receive(:visit_process_reference).with(:process)
        expect(visitor).to receive(:visit_task_reference).with(:next)
        expect(visitor).to receive(:visit_args).with(:options)
        expect(visitor).to receive(:visit_process).with(:sub_process)
        expect(visitor).to receive(:visit_attribute).with(:queue)
        expect(visitor).to receive(:visit_attribute_time).with(:created_at)
        expect(visitor).to receive(:visit_attribute_time).with(:updated_at)

        subject.accept(visitor)
      }
    end

    describe "#inspect" do
      it { expect(subject.inspect).to_not be_nil }
    end
  end

end
