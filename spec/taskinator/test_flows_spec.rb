require 'spec_helper'

describe TestFlows do

  [
    TestFlows::Task,
    TestFlows::Job,
    TestFlows::SubProcess,
    TestFlows::Sequential,
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

        it "invokes each task" do
          # this doesn't work...
          # expect_any_instance_of(Taskinator::Executor).to receive(:do_task_x).exactly(3).times
          # subject.start!

          expect {
            subject.enqueue!
          }.to change { Taskinator.queue.tasks.length }.by(3)
        end
      end

      context "concurrent" do
        let(:definition) { TestFlows::EmptyConcurrentProcessTest }
        subject { definition.create_process }

        it "invokes each task" do
          # this doesn't work...
          # expect_any_instance_of(Taskinator::Executor).to receive(:do_task_x).exactly(3).times
          # subject.start!

          expect {
            subject.enqueue!
          }.to change { Taskinator.queue.tasks.length }.by(3)
        end
      end

    end
  end

end
