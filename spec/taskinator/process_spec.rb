require 'spec_helper'

describe Taskinator::Process do

  let(:definition) { TestDefinition }

  describe "Base" do

    subject do
      Class.new(Taskinator::Process) do
        include ProcessMethods
      end.new(definition)
    end

    describe "#initialize" do
      it { expect(subject.uuid).to_not be_nil }
      it { expect(subject.definition).to_not be_nil }
      it { expect(subject.definition).to eq(definition) }
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

    describe "#tasks" do
      it { expect(subject.tasks).to be_a(Taskinator::Tasks) }
    end

    describe "#no_tasks_defined?" do
      it { expect(subject.no_tasks_defined?).to be }
      it {
        subject.tasks << :mock
        expect(subject.no_tasks_defined?).to_not be
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
        process = Class.new(Taskinator::Process).new(definition, :queue => :foo)
        expect(process.queue).to eq(:foo)
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
          expect(subject.current_state).to eq(:initial)
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
          expect(subject.current_state).to eq(:initial)
          subject.start!
          expect(subject.current_state).to eq(:processing)
        }
      end

      describe "#cancel!" do
        it { expect(subject).to respond_to(:cancel!) }
        it {
          expect(subject).to receive(:cancel)
          subject.cancel!
        }
        it {
          expect(subject.current_state).to eq(:initial)
          subject.cancel!
          expect(subject.current_state).to eq(:cancelled)
        }
      end

      describe "#pause!" do
        it { expect(subject).to respond_to(:pause!) }
        it {
          expect(subject).to receive(:pause)
          subject.start!
          subject.pause!
        }
        it {
          subject.start!
          subject.pause!
          expect(subject.current_state).to eq(:paused)
        }
      end

      describe "#resume!" do
        it { expect(subject).to respond_to(:resume!) }
        it {
          expect(subject).to receive(:resume)
          subject.start!
          subject.pause!
          subject.resume!
        }
        it {
          subject.start!
          subject.pause!
          subject.resume!
          expect(subject.current_state).to eq(:processing)
        }
      end

      describe "#complete!" do
        it { expect(subject).to respond_to(:complete!) }
        it {
          allow(subject).to receive(:tasks_completed?) { true }
          expect(subject).to receive(:complete)
          subject.start!
          subject.complete!
        }
        it {
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
          subject.start!
          subject.fail!(error)
        }
        it {
          subject.start!
          subject.fail!(StandardError.new)
          expect(subject.current_state).to eq(:failed)
        }
      end
    end

    describe "#parent" do
      it "notifies parent when completed" do
        allow(subject).to receive(:tasks_completed?) { true }
        subject.parent = double('parent', :uuid => 'foobar')
        expect(subject.parent).to receive(:complete!)
        subject.start!
        subject.complete!
      end

      it "notifies parent when failed" do
        allow(subject).to receive(:tasks_completed?) { true }
        subject.parent = double('parent', :uuid => 'foobar')
        expect(subject.parent).to receive(:fail!)
        subject.start!
        subject.fail!(StandardError.new)
      end
    end

    describe "persistence" do
      it { expect(subject).to be_a(Taskinator::Persistence) }

      it {
        expect(subject).to receive(:accept)
        subject.save
      }

      it {
        visitor = double('visitor')
        expect(visitor).to receive(:visit_type).with(:definition)
        expect(visitor).to receive(:visit_attribute).with(:uuid)
        expect(visitor).to receive(:visit_args).with(:options)
        expect(visitor).to receive(:visit_task_reference).with(:parent)
        expect(visitor).to receive(:visit_tasks)
        expect(visitor).to receive(:visit_attribute).with(:scope)
        expect(visitor).to receive(:visit_attribute).with(:queue)
        expect(visitor).to receive(:visit_attribute_time).with(:created_at)
        expect(visitor).to receive(:visit_attribute_time).with(:updated_at)

        subject.accept(visitor)
      }
    end

    describe "#tasks_count" do
      it {
        expect(subject.tasks_count).to eq(0)
      }
    end

  end

  describe Taskinator::Process::Sequential do

    subject { Taskinator::Process.define_sequential_process_for(definition) }

    it_should_behave_like "a process", Taskinator::Process::Sequential

    let(:tasks) {
      [
        Class.new(Taskinator::Task).new(subject),
        Class.new(Taskinator::Task).new(subject)
      ]
    }

    describe ".define_sequential_process_for" do
      it "raise error for nil definition" do
        expect {
          Taskinator::Process.define_sequential_process_for(nil)
        }.to raise_error(ArgumentError)
      end

      it "raise error for invalid definition" do
        expect {
          Taskinator::Process.define_sequential_process_for(Object)
        }.to raise_error(ArgumentError)
      end

      it "sets the queue to use" do
        process = Taskinator::Process.define_sequential_process_for(definition, :queue => :foo)
        expect(process.queue).to eq(:foo)
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

      it "delegates to the first task" do
        task = double('task')
        expect(task).to receive(:enqueue!)
        allow(subject).to receive(:tasks).and_return([task])

        subject.enqueue!
      end
    end

    describe "#start!" do
      it "executes the first task" do
        tasks.each {|t| subject.tasks << t }
        task1 = tasks[0]

        expect(subject.tasks).to receive(:first).and_call_original
        expect(task1).to receive(:start!)

        subject.start!
      end

      it "completes if no tasks" do
        expect(subject).to receive(:complete!)
        subject.start!
      end
    end

    describe "#task_completed" do
      it "executes the next task" do
        tasks.each {|t| subject.tasks << t }
        task1 = tasks[0]
        task2 = tasks[1]

        expect(task1).to receive(:next).and_call_original
        expect(task2).to receive(:enqueue!)

        subject.task_completed(task1)
      end

      it "deincrements the pending task count" do
        tasks.each {|t| subject.tasks << t }
        task1 = tasks[0]
        task2 = tasks[1]

        allow(task2).to receive(:enqueue!)

        pending_count = tasks.count
        allow(subject).to receive(:deincr_pending_tasks) { pending_count -= 1 }

        subject.task_completed(task1)
        expect(pending_count).to eq(tasks.count - 1)

        subject.task_completed(task2)
        expect(pending_count).to eq(tasks.count - 2)
      end

      it "completes if no more tasks" do
        tasks.each {|t| subject.tasks << t }
        task2 = tasks[1]

        expect(subject).to receive(:complete!)

        subject.task_completed(task2)
      end

      it "completes if failed task gets retried" do
        tasks.each {|t| subject.tasks << t }
        task1 = tasks[0]
        task2 = tasks[1]

        allow(task2).to receive(:enqueue!)

        expect(subject).to receive(:fail!).and_call_original
        expect(subject).to receive(:complete!).and_call_original

        subject.task_completed(task1)
        expect(subject.completed?).to_not be
        expect(subject.failed?).to_not be

        subject.task_failed(task2, StandardError.new)
        expect(subject.completed?).to_not be
        expect(subject.failed?).to be

        # "retry" the task
        subject.task_completed(task2)
        expect(subject.completed?).to be
        expect(subject.failed?).to_not be
      end
    end

    describe "#tasks_completed?" do
      it "one or more tasks are incomplete" do
        tasks.each {|t| subject.tasks << t }

        expect(subject.tasks_completed?).to_not be
      end

      it "all tasks are complete" do
        tasks.each {|t|
          subject.tasks << t
          allow(t).to receive(:completed?) { true }
        }

        expect(subject.tasks_completed?).to be
      end
    end

    describe "#task_failed" do
      it "fails when tasks fail" do
        tasks.each {|t| subject.tasks << t }

        error = StandardError.new

        expect(subject).to receive(:fail!).with(error)

        subject.task_failed(tasks.first, error)
      end

      it "doesn't deincement pending task count" do
        tasks.each {|t| subject.tasks << t }

        expect(subject).to_not receive(:deincr_pending_tasks)

        error = StandardError.new

        subject.task_failed(tasks.first, error)
      end
    end

    describe "#accept" do
      it { expect(subject).to be_a(Taskinator::Persistence) }

      it {
        expect(subject).to receive(:accept)
        subject.save
      }

      it {
        visitor = double('visitor')
        expect(visitor).to receive(:visit_type).with(:definition)
        expect(visitor).to receive(:visit_attribute).with(:uuid)
        expect(visitor).to receive(:visit_args).with(:options)
        expect(visitor).to receive(:visit_task_reference).with(:parent)
        expect(visitor).to receive(:visit_tasks)
        expect(visitor).to receive(:visit_attribute).with(:scope)
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

  describe Taskinator::Process::Concurrent do

    let(:complete_on) { Taskinator::CompleteOn::Default }

    subject { Taskinator::Process.define_concurrent_process_for(definition, complete_on) }

    it_should_behave_like "a process", Taskinator::Process::Concurrent do

      it { expect(subject.complete_on).to eq(Taskinator::CompleteOn::Default)  }

    end

    let(:tasks) {
      [
        Class.new(Taskinator::Task).new(subject),
        Class.new(Taskinator::Task).new(subject)
      ]
    }

    describe ".define_concurrent_process_for" do
      it "raise error for nil definition" do
        expect {
          Taskinator::Process.define_concurrent_process_for(nil)
        }.to raise_error(ArgumentError)
      end

      it "raise error for invalid definition" do
        expect {
          Taskinator::Process.define_concurrent_process_for(Object)
        }.to raise_error(ArgumentError)
      end

      it "sets the queue to use" do
        process = Taskinator::Process.define_concurrent_process_for(definition, Taskinator::CompleteOn::First, :queue => :foo)
        expect(process.queue).to eq(:foo)
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

      it "delegates to all the tasks" do
        tasks.each {|t|
          subject.tasks << t
          expect(t).to receive(:enqueue!)
        }

        subject.enqueue!
      end
    end

    describe "#start!" do
      it "executes all tasks" do
        tasks.each {|t|
          subject.tasks << t
          expect(t).to receive(:start!)
        }

        subject.start!
      end

      it "completes if no tasks" do
        expect(subject).to receive(:complete!)
        subject.start!
      end
    end

    describe "#task_completed" do
      it "completes when tasks complete (CompleteOn::First)" do
        process = Taskinator::Process.define_concurrent_process_for(definition, Taskinator::CompleteOn::First)
        tasks.each {|t| process.tasks << t }

        pending_count = tasks.count
        allow(process).to receive(:deincr_pending_tasks) { pending_count -= 1 }

        expect(process).to receive(:complete!).once.and_call_original

        process.task_completed(tasks.first)

        expect(process.completed?).to be(true)

        # remaining tasks should do nothing...
        tasks.each do |task|
          process.task_completed(task)
        end
      end

      it "completes when tasks complete (CompleteOn::Last)" do
        process = Taskinator::Process.define_concurrent_process_for(definition, Taskinator::CompleteOn::Last)
        tasks.each {|t| process.tasks << t }

        pending_count = tasks.count
        allow(process).to receive(:deincr_pending_tasks) { pending_count -= 1 }

        expect(process).to receive(:complete!).once.and_call_original

        tasks.each do |task|
          process.task_completed(task)
          expect(process.completed?).to be(false) unless pending_count < 1
        end
      end

      it "deincrements the pending task count" do
        tasks.each {|t| subject.tasks << t }
        task1 = tasks[0]
        task2 = tasks[1]

        pending_count = tasks.count
        allow(subject).to receive(:deincr_pending_tasks) { pending_count -= 1 }

        subject.task_completed(task1)
        expect(pending_count).to eq(tasks.count - 1)

        subject.task_completed(task2)
        expect(pending_count).to eq(tasks.count - 2)
      end

      describe "completes if failed task gets retried" do
        it "after first task succeeds" do
          tasks.each {|t| subject.tasks << t }
          task1 = tasks[0]
          task2 = tasks[1]

          pending_count = tasks.count
          allow(subject).to receive(:deincr_pending_tasks) { pending_count -= 1 }
          allow(task2).to receive(:enqueue!)

          expect(subject).to receive(:fail!).and_call_original
          expect(subject).to receive(:complete!).and_call_original

          # first task succeeds
          subject.task_completed(task1)
          expect(pending_count).to eq(tasks.count - 1)

          # second task fails
          subject.task_failed(task2, StandardError.new)

          expect(subject.failed?).to be
          expect(pending_count).to eq(tasks.count - 1)

          # "retry" the task
          subject.task_completed(task2)

          expect(pending_count).to eq(tasks.count - 2)
          expect(subject.failed?).to_not be
          expect(subject.completed?).to be
        end

        it "after first task fails" do
          tasks.each {|t| subject.tasks << t }
          task1 = tasks[0]
          task2 = tasks[1]

          pending_count = tasks.count
          allow(subject).to receive(:deincr_pending_tasks) { pending_count -= 1 }
          allow(task2).to receive(:enqueue!)

          expect(subject).to receive(:fail!).and_call_original
          expect(subject).to receive(:complete!).and_call_original

          # first task fails
          subject.task_failed(task2, StandardError.new)
          expect(subject.failed?).to be
          expect(pending_count).to eq(tasks.count)

          # second task succeeds
          subject.task_completed(task1)
          expect(pending_count).to eq(tasks.count - 1)

          # "retry" the task
          subject.task_completed(task2)

          expect(pending_count).to eq(tasks.count - 2)
          expect(subject.failed?).to_not be
          expect(subject.completed?).to be
        end
      end
    end

    describe "#task_failed" do
      it "fails when tasks fail" do
        tasks.each {|t| subject.tasks << t }

        error = StandardError.new

        expect(subject).to receive(:fail!).with(error)

        subject.task_failed(tasks.first, error)
      end

      it "doesn't deincement pending task count" do
        tasks.each {|t| subject.tasks << t }

        expect(subject).to_not receive(:deincr_pending_tasks)

        error = StandardError.new

        subject.task_failed(tasks.first, error)
      end
    end

    describe "#tasks_completed?" do

      describe "complete on first" do
        let(:process) { Taskinator::Process.define_concurrent_process_for(definition, Taskinator::CompleteOn::First) }

        it "yields false when no tasks have completed" do
          tasks.each {|t| process.tasks << t }

          expect(process.tasks_completed?).to_not be
        end

        it "yields true when one or more tasks have completed" do
          tasks.each {|t|
            process.tasks << t
            allow(t).to receive(:completed?) { true }
          }

          expect(process.tasks_completed?).to be
        end
      end

      describe "complete on last" do
        let(:process) { Taskinator::Process.define_concurrent_process_for(definition, Taskinator::CompleteOn::Last) }

        it "yields false when no tasks have completed" do
          tasks.each {|t| process.tasks << t }

          expect(process.tasks_completed?).to_not be
        end

        it "yields false when one, but not all, tasks have completed" do
          tasks.each {|t| process.tasks << t }
          allow(tasks.first).to receive(:completed?) { true }

          expect(process.tasks_completed?).to_not be
        end

        it "yields true when all tasks have completed" do
          tasks.each {|t|
            process.tasks << t
            allow(t).to receive(:completed?) { true }
          }

          expect(process.tasks_completed?).to be
        end
      end
    end

    describe "#accept" do
      it { expect(subject).to be_a(Taskinator::Persistence) }

      it {
        expect(subject).to receive(:accept)
        subject.save
      }

      it {
        visitor = double('visitor')
        expect(visitor).to receive(:visit_type).with(:definition)
        expect(visitor).to receive(:visit_attribute).with(:uuid)
        expect(visitor).to receive(:visit_attribute_enum).with(:complete_on, Taskinator::CompleteOn)
        expect(visitor).to receive(:visit_args).with(:options)
        expect(visitor).to receive(:visit_task_reference).with(:parent)
        expect(visitor).to receive(:visit_tasks)
        expect(visitor).to receive(:visit_attribute).with(:scope)
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
