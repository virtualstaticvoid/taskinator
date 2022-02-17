require 'spec_helper'

describe TestFlows do

  [
    TestFlows::Task,
    TestFlows::Job,
    TestFlows::SubProcess,
    TestFlows::Sequential
  ].each do |definition|

    describe definition.name do

      it "should have one task" do
        process = definition.create_process(1)
        expect(process.tasks_count).to eq(1)
      end

      it "should have 3 tasks" do
        process = definition.create_process(3)
        expect(process.tasks_count).to eq(3)
      end

      %w(
        failed
        cancelled
        completed
      ).each do |status|

        describe "count_#{status}" do
          it {
            process = definition.create_process(1)
            expect(process.send(:"count_#{status}")).to eq(0)
          }

          it {
            process = definition.create_process(2)
            expect(process.send(:"count_#{status}")).to eq(0)
          }
        end

        describe "incr_#{status}" do
          it {
            process = definition.create_process(1)
            process.send(:"incr_#{status}")
            expect(process.send(:"count_#{status}")).to eq(1)
          }

          it {
            process = definition.create_process(4)
            4.times do |i|
              process.send(:"incr_#{status}")
              expect(process.send(:"count_#{status}")).to eq(i + 1)
            end
          }

          it "should increment completed count" do
            process = definition.create_process(10)
            recursively_enumerate_tasks(process.tasks) do |task|
              task.send(:"incr_#{status}")
            end
            expect(process.send(:"count_#{status}")).to eq(10)
          end
        end

        describe "percentage_#{status}" do
          it {
            process = definition.create_process(1)
            expect(process.send(:"percentage_#{status}")).to eq(0.0)
          }

          it {
            process = definition.create_process(4)
            expect(process.send(:"percentage_#{status}")).to eq(0.0)

            count = 4
            count.times do |i|
              process.send(:"incr_#{status}")
              expect(process.send(:"percentage_#{status}")).to eq( ((i + 1.0) / count) * 100.0 )
            end
          }
        end

      end
    end
  end

  describe "scenarios" do

    before do
      # use the "synchronous" queue
      Taskinator.queue_adapter = :test_queue_worker
    end

    context "empty subprocesses" do

      context "sequential" do
        let(:definition) { TestFlows::EmptySequentialProcessTest }
        subject { definition.create_process }

        it "contains 3 tasks" do
          expect(subject.tasks.length).to eq(3)
        end

        it "invokes each task" do
          expect_any_instance_of(definition).to receive(:task_0)
          expect_any_instance_of(definition).to receive(:task_1)
          expect_any_instance_of(definition).to receive(:task_2)

          expect {
            subject.enqueue!
          }.to change { Taskinator.queue.tasks.length }.by(3)
        end
      end

      context "concurrent" do
        let(:definition) { TestFlows::EmptyConcurrentProcessTest }
        subject { definition.create_process }

        it "contains 3 tasks" do
          expect(subject.tasks.length).to eq(3)
        end

        it "invokes each task" do
          expect_any_instance_of(definition).to receive(:task_0)
          expect_any_instance_of(definition).to receive(:task_1)
          expect_any_instance_of(definition).to receive(:task_2)

          expect {
            subject.enqueue!
          }.to change { Taskinator.queue.tasks.length }.by(3)
        end
      end

    end
  end

  describe "statuses" do
    describe "task" do
      before do
        # override enqueue
        allow_any_instance_of(Taskinator::Task::Step).to receive(:enqueue!) { |task|
          # emulate the worker starting the task
          task.start!
        }
      end

      let(:task_count) { 2 }
      let(:definition) { TestFlows::Task }
      subject { definition.create_process(task_count) }

      it "reports process and task state" do

        instrumenter = TestInstrumenter.new do |name, payload|

          case name
          when 'taskinator.process.created', 'taskinator.process.saved'
            expect(payload[:state]).to eq(:initial)
          when 'taskinator.process.processing'
            expect(payload[:state]).to eq(:processing)
          when 'taskinator.task.processing'
            expect(payload[:state]).to eq(:processing)
          when 'taskinator.task.completed'
            expect(payload[:state]).to eq(:completed)
          when 'taskinator.process.completed'
            expect(payload[:state]).to eq(:completed)
          else
            raise "Unknown event '#{name}'."
          end

        end

        allow(Taskinator).to receive(:instrumenter).and_return(instrumenter)
        expect(instrumenter).to receive(:instrument).at_least(task_count).times.and_call_original

        expect(subject.current_state).to eq(:initial)

        subject.start!
      end

    end

    describe "job" do
      pending
    end

    describe "subprocess" do
      pending
    end
  end

  describe "instrumentation" do
    describe "task" do
      before do
        # override enqueue
        allow_any_instance_of(Taskinator::Task::Step).to receive(:enqueue!) { |task|
          # emulate the worker starting the task
          task.start!
        }
      end

      let(:task_count) { 10 }
      let(:definition) { TestFlows::Task }
      subject { definition.create_process(task_count) }

      it "reports task completed" do
        block = SpecSupport::Block.new
        expect(block).to receive(:call).exactly(task_count).times

        TestInstrumenter.subscribe(block, /taskinator.task.completed/) do
          subject.start!
        end
      end

      it "reports process completed" do
        block = SpecSupport::Block.new
        expect(block).to receive(:call).once

        TestInstrumenter.subscribe(block, /taskinator.process.completed/) do
          subject.start!
        end
      end

      it "reports task percentage completed" do
        invoke_count = 0

        instrumenter = TestInstrumenter.new do |name, payload|
          if name =~ /taskinator.task.processing/
            expect(payload[:percentage_completed]).to eq( (invoke_count / task_count.to_f) * 100.0 )
          elsif name =~ /taskinator.task.completed/
            invoke_count += 1
            expect(payload[:percentage_completed]).to eq( (invoke_count / task_count.to_f) * 100.0 )
          end
        end

        allow(Taskinator).to receive(:instrumenter).and_return(instrumenter)
        expect(instrumenter).to receive(:instrument).at_least(task_count).times.and_call_original

        subject.start!
      end

      it "reports process percentage completed" do
        instrumenter = TestInstrumenter.new do |name, payload|
          if name =~ /taskinator.process.started/
            expect(payload[:process_uuid]).to eq(subject.uuid)
          elsif name =~ /taskinator.process.completed/
            expect(payload[:percentage_completed]).to eq(100.0)
          end
        end

        allow(Taskinator).to receive(:instrumenter).and_return(instrumenter)
        expect(instrumenter).to receive(:instrument).at_least(task_count).times.and_call_original

        subject.start!
      end

    end

    describe "job" do
      before do
        # override enqueue
        allow_any_instance_of(Taskinator::Task::Job).to receive(:enqueue!) { |task|
          # emulate the worker starting the task
          task.start!
        }
      end

      let(:task_count) { 10 }
      let(:definition) { TestFlows::Job }
      subject { definition.create_process(task_count) }

      it "reports task completed" do
        block = SpecSupport::Block.new
        expect(block).to receive(:call).exactly(task_count).times

        TestInstrumenter.subscribe(block, /taskinator.task.completed/) do
          subject.start!
        end
      end

      it "reports process completed" do
        block = SpecSupport::Block.new
        expect(block).to receive(:call).once

        TestInstrumenter.subscribe(block, /taskinator.process.completed/) do
          subject.start!
        end
      end

      it "reports task percentage completed" do
        invoke_count = 0

        instrumenter = TestInstrumenter.new do |name, payload|
          if name =~ /taskinator.task.processing/
            expect(payload[:percentage_completed]).to eq( (invoke_count / task_count.to_f) * 100.0 )
          elsif name =~ /taskinator.task.completed/
            invoke_count += 1
            expect(payload[:percentage_completed]).to eq( (invoke_count / task_count.to_f) * 100.0 )
          end
        end

        allow(Taskinator).to receive(:instrumenter).and_return(instrumenter)
        expect(instrumenter).to receive(:instrument).at_least(task_count).times.and_call_original

        subject.start!
      end

      it "reports process percentage completed" do
        instrumenter = TestInstrumenter.new do |name, payload|
          if name =~ /taskinator.process.started/
            expect(payload[:process_uuid]).to eq(subject.uuid)
          elsif name =~ /taskinator.process.completed/
            expect(payload[:percentage_completed]).to eq(100.0)
          end
        end

        allow(Taskinator).to receive(:instrumenter).and_return(instrumenter)
        expect(instrumenter).to receive(:instrument).at_least(task_count).times.and_call_original

        subject.start!
      end

    end

    describe "sub process" do
      before do
        # override enqueue
        allow_any_instance_of(Taskinator::Task::Step).to receive(:enqueue!) { |task|
          # emulate the worker starting the task
          task.start!
        }

        # override enqueue
        allow_any_instance_of(Taskinator::Task::SubProcess).to receive(:enqueue!) { |task|
          # emulate the worker starting the task
          task.start!
        }
      end

      let(:task_count) { 10 }
      let(:definition) { TestFlows::SubProcess }
      subject { definition.create_process(task_count) }

      it "reports task completed" do
        block = SpecSupport::Block.new

        # NOTE: sub process counts for one task
        expect(block).to receive(:call).exactly(task_count + 1).times

        TestInstrumenter.subscribe(block, /taskinator.task.completed/) do
          subject.start!
        end
      end

      it "reports process completed" do
        block = SpecSupport::Block.new
        expect(block).to receive(:call).twice # includes sub process

        TestInstrumenter.subscribe(block, /taskinator.process.completed/) do
          subject.start!
        end
      end

      it "reports task percentage completed" do
        invoke_count = 0

        instrumenter = TestInstrumenter.new do |name, payload|
          if name =~ /taskinator.task.processing/
            expect(payload[:percentage_completed]).to eq( (invoke_count / task_count.to_f) * 100.0 )
          elsif name =~ /taskinator.task.completed/
            unless payload.type.constantize >= Taskinator::Task::SubProcess
              invoke_count += 1
              expect(payload[:percentage_completed]).to eq( (invoke_count / task_count.to_f) * 100.0 )
            end
          end
        end

        allow(Taskinator).to receive(:instrumenter).and_return(instrumenter)
        expect(instrumenter).to receive(:instrument).at_least(task_count).times.and_call_original

        subject.start!
      end

      it "reports process percentage completed" do
        instrumenter = TestInstrumenter.new do |name, payload|
          if name =~ /taskinator.process.started/
            expect(payload[:process_uuid]).to eq(subject.uuid)
          elsif name =~ /taskinator.process.completed/
            expect(payload[:percentage_completed]).to eq(100.0)
          end
        end

        allow(Taskinator).to receive(:instrumenter).and_return(instrumenter)

        # NOTE: sub process counts for one task
        expect(instrumenter).to receive(:instrument).at_least(task_count + 1).times.and_call_original

        subject.start!
      end

    end
  end

end
