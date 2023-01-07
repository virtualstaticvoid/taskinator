require 'spec_helper'

describe Taskinator::Persistence, :redis => true do

  let(:definition) { TestDefinitions::Definition }

  describe "class methods" do
    subject {
      Class.new do
        include Taskinator::Persistence
      end
    }

    describe ".key_for" do
      before do
        allow(subject).to receive(:base_key) { 'base_key' }
      end

      it {
        expect(subject.key_for('uuid')).to match(/base_key/)
        expect(subject.key_for('uuid')).to match(/uuid/)
      }
    end

    describe ".fetch" do
      before do
        allow(subject).to receive(:base_key) { 'base_key' }
      end

      it "fetches instance" do
        item = double('item')
        expect_any_instance_of(Taskinator::Persistence::RedisDeserializationVisitor).to receive(:visit) { item }
        expect(subject.fetch('uuid')).to eq(item)
      end

      it "fetches instance, and adds to cache" do
        cache = {}
        allow_any_instance_of(Taskinator::Persistence::RedisDeserializationVisitor).to receive(:visit) { true }
        subject.fetch('uuid', cache)
        expect(cache.key?(subject.key_for('uuid'))).to be
      end

      it "fetches instance from cache" do
        item = double('item')
        cache = { subject.key_for('uuid') => item }
        expect(subject.fetch('uuid', cache)).to eq(item)
      end

      it "yields UnknownType" do
        Taskinator.redis do |conn|
          conn.hmset(*[subject.key_for("foo"), [:type, 'UnknownFoo']])
        end
        instance = subject.fetch("foo")
        expect(instance).to be_a(Taskinator::Persistence::UnknownType)
        expect(instance.type).to eq("UnknownFoo")
      end

      describe "for processes" do
        let(:process) { TestProcess.new(definition) }

        it {
          process.save
          expect(TestProcess.fetch(process.uuid)).to eq(process)
        }

        describe "unknown definition" do
          it "yields UnknownType" do
            Taskinator.redis do |conn|
              conn.hmset(*[process.key, [:type, TestProcess.name], [:uuid, process.uuid], [:definition, 'UnknownFoo']])
            end

            instance = TestProcess.fetch(process.uuid)
            expect(instance.uuid).to eq(process.uuid)
            expect(instance.definition).to be_a(Taskinator::Persistence::UnknownType)
            expect(instance.definition.type).to eq("UnknownFoo")
          end
        end
      end

      describe "for tasks" do
        let(:process) { TestProcess.new(definition) }
        let(:task) { TestTask.new(process) }

        it {
          process.tasks << task
          process.save

          instance = TestTask.fetch(task.uuid)
          expect(instance).to eq(task)
          expect(instance.process).to eq(process)
        }

        describe "unknown job" do
          let(:task) { TestJobTask.new(process, TestJob, []) }

          it "yields UnknownType" do
            Taskinator.redis do |conn|
              conn.hmset(*[task.key, [:type, task.class.name], [:uuid, task.uuid], [:job, 'UnknownBar']])
            end

            instance = TestJobTask.fetch(task.uuid)
            expect(instance.uuid).to eq(task.uuid)
            expect(instance.job).to be_a(Taskinator::Persistence::UnknownType)
            expect(instance.job.type).to eq("UnknownBar")
          end
        end

        describe "unknown subprocess" do
          let(:sub_process) { TestProcess.new(definition) }
          let(:task) { TestSubProcessTask.new(process, sub_process) }

          it "yields UnknownType" do
            Taskinator.redis do |conn|
              conn.multi do |transaction|
                transaction.hmset(*[task.key, [:type, task.class.name], [:uuid, task.uuid], [:sub_process, sub_process.uuid]])
                transaction.hmset(*[sub_process.key, [:type, sub_process.class.name], [:uuid, sub_process.uuid], [:definition, 'UnknownBaz']])
              end
            end

            instance = TestSubProcessTask.fetch(task.uuid)
            expect(instance.uuid).to eq(task.uuid)
            expect(instance.sub_process.definition).to be_a(Taskinator::Persistence::UnknownType)
            expect(instance.sub_process.definition.type).to eq("UnknownBaz")
          end
        end
      end
    end
  end

  describe "serialization helpers" do
    subject { Taskinator::Persistence }

    describe "#serialize" do
      describe "Array" do
        it {
          expect(subject.serialize([])).to eq(YAML.dump([]))
        }

        it {
          expect(subject.serialize([1])).to eq(YAML.dump([1]))
        }

        it {
          expect(subject.serialize(["string"])).to eq(YAML.dump(["string"]))
        }

        it {
          expect(subject.serialize([MockModel.new])).to eq("---\n- !ruby/object:MockModel\n  model_id: 1\n  model_type: TypeX\n")
        }
      end

      describe "Hash" do
        it {
          expect(subject.serialize({:foo => :bar})).to eq(YAML.dump({:foo => :bar}))
        }

        it {
          expect(subject.serialize({:foo => 1})).to eq(YAML.dump({:foo => 1}))
        }

        it {
          expect(subject.serialize({:foo => "string"})).to eq(YAML.dump({:foo => "string"}))
        }

        it {
          expect(subject.serialize({:foo => MockModel.new})).to eq("---\n:foo: !ruby/object:MockModel\n  model_id: 1\n  model_type: TypeX\n")
        }
      end

      describe "Object" do
        it {
          expect(subject.serialize(:foo)).to eq(YAML.dump(:foo))
        }

        it {
          expect(subject.serialize(1)).to eq(YAML.dump(1))
        }

        it {
          expect(subject.serialize("string")).to eq(YAML.dump("string"))
        }

        it {
          expect(subject.serialize(MockModel.new)).to eq("--- !ruby/object:MockModel\nmodel_id: 1\nmodel_type: TypeX\n")
        }
      end
    end

    describe "#deserialize" do
      describe "Array" do
        it {
          expect(subject.deserialize(YAML.dump([]))).to eq([])
        }

        it {
          expect(subject.deserialize(YAML.dump([1]))).to eq([1])
        }

        it {
          expect(subject.deserialize(YAML.dump(["string"]))).to eq(["string"])
        }

        it {
          expect_any_instance_of(MockModel).to receive(:find)
          subject.deserialize("---\n!ruby/object:MockModel\n  model_id: 1\n  model_type: TypeX\n")
        }
      end

      describe "Hash" do
        it {
          expect(subject.deserialize(YAML.dump({:foo => :bar}))).to eq({:foo => :bar})
        }

        it {
          expect(subject.deserialize(YAML.dump({:foo => 1}))).to eq({:foo => 1})
        }

        it {
          expect(subject.deserialize(YAML.dump({:foo => "string"}))).to eq({:foo => "string"})
        }

        it {
          expect_any_instance_of(MockModel).to receive(:find)
          subject.deserialize("---\n:foo: !ruby/object:MockModel\n  model_id: 1\n  model_type: TypeX\n")
        }
      end

      describe "Object" do
        it {
          expect(subject.deserialize(YAML.dump(:foo))).to eq(:foo)
        }

        it {
          expect(subject.deserialize(YAML.dump(1))).to eq(1)
        }

        it {
          expect(subject.deserialize(YAML.dump("string"))).to eq("string")
        }

        it {
          expect_any_instance_of(MockModel).to receive(:find)
          subject.deserialize("---\n!ruby/object:MockModel\n  model_id: 1\n  model_type: TypeX\n")
        }
      end
    end
  end

  describe "unknown type helpers" do
    subject { Taskinator::Persistence::UnknownType }

    describe "#new" do
      it "instantiates new module instance" do
        instance = subject.new("foo")
        expect(instance).to_not be_nil
        expect(instance).to be_a(::Module)
      end

      it "yields same instance for same type" do
        instance1 = subject.new("foo")
        instance2 = subject.new("foo")
        expect(instance1).to eq(instance2)
      end
    end

    describe ".type" do
      it {
        instance = subject.new("foo")
        expect(instance.type).to eq("foo")
      }
    end

    describe ".to_s" do
      it {
        instance = subject.new("foo")
        expect(instance.to_s).to eq("Unknown type 'foo'.")
      }
    end

    describe ".allocate" do
      it "emulates Object#allocate" do
        instance = subject.new("foo")
        expect(instance.allocate).to eq(instance)
      end
    end

    describe ".accept" do
      it {
        instance = subject.new("foo")
        expect(instance).to respond_to(:accept)
      }
    end

    describe ".perform" do
      it "raises UnknownTypeError" do
        instance = subject.new("foo")
        expect {
          instance.perform(:foo, 1, false)
        }.to raise_error(Taskinator::Persistence::UnknownTypeError)
      end
    end

    describe "via executor" do
      it "raises UnknownTypeError" do
        instance = subject.new("foo")
        executor = Taskinator::Executor.new(instance)

        expect {
          executor.foo
        }.to raise_error(Taskinator::Persistence::UnknownTypeError)
      end
    end
  end

  describe "instance methods" do
    subject {
      klass = Class.new do
        include Taskinator::Persistence

        def self.base_key
          'base_key'
        end

        attr_reader :uuid

        def initialize
          @uuid = Taskinator.generate_uuid
        end
      end
      klass.new
    }

    describe "#save" do
      pending
    end

    describe "#to_xml" do
      it {
        process = TestDefinitions::NestedTask.create_process(1)
        expect(process.to_xml).to match(/xml/)
      }
    end

    describe "#key" do
      it {
        expect(subject.key).to match(/#{subject.uuid}/)
      }
    end

    describe "#process_uuid" do
      it {
        Taskinator.redis do |conn|
          conn.hset(subject.key, :process_uuid, subject.uuid)
        end

        expect(subject.process_uuid).to match(/#{subject.uuid}/)
      }
    end

    describe "#process_key" do
      it {
        Taskinator.redis do |conn|
          conn.hset(subject.key, :process_uuid, subject.uuid)
        end

        expect(subject.process_key).to match(/#{subject.uuid}/)
      }
    end

    describe "#load_workflow_state" do
      it {
        expect(subject.load_workflow_state).to eq(:initial)
      }
    end

    describe "#persist_workflow_state" do
      it {
        subject.persist_workflow_state(:active)
        expect(subject.load_workflow_state).to eq(:active)
      }
    end

    describe "#fail" do
      it "persists error information" do
        begin
          # raise this error in a block, so there is a backtrace!
          raise StandardError.new('a error')
        rescue => e
          subject.fail(e)
        end

        type, message, backtrace = Taskinator.redis do |conn|
          conn.hmget(subject.key, :error_type, :error_message, :error_backtrace)
        end

        expect(type).to eq('StandardError')
        expect(message).to eq('a error')
        expect(backtrace).to_not be_empty
      end
    end

    describe "#error" do
      it "retrieves error information" do
        error = nil
        begin
          # raise this error in a block, so there is a backtrace!
          raise StandardError.new('a error')
        rescue => e
          error = e
          subject.fail(error)
        end

        expect(subject.error).to eq([error.class.name, error.message, error.backtrace])
      end
    end

    describe "#tasks_count" do
      it {
        Taskinator.redis do |conn|
          conn.hset(subject.process_key, :tasks_count, 99)
        end

        expect(subject.tasks_count).to eq(99)
      }
    end

    %w(
      failed
      cancelled
      completed
    ).each do |status|

      describe "#count_#{status}" do
        it {
          Taskinator.redis do |conn|
            conn.hset(subject.process_key, "tasks_#{status}", 99)
          end

          expect(subject.send(:"count_#{status}")).to eq(99)
        }
      end

      describe "#incr_#{status}" do
        it {
          Taskinator.redis do |conn|
            conn.hset(subject.process_key, "tasks_#{status}", 99)
          end

          subject.send(:"incr_#{status}")

          expect(subject.send(:"count_#{status}")).to eq(100)
        }
      end

      describe "#percentage_#{status}" do
        it {
          Taskinator.redis do |conn|
            conn.hmset(
              subject.process_key,
              [:tasks_count, 100],
              ["tasks_#{status}", 1]
            )
          end

          expect(subject.send(:"percentage_#{status}")).to eq(1.0)
        }
      end

    end

    describe "#deincr_pending_tasks" do
      it {
        Taskinator.redis do |conn|
          conn.set("#{subject.key}.pending", 99)
        end

        pending = subject.deincr_pending_tasks

        expect(pending).to eq(98)
      }
    end

    describe "#process_options" do
      it {
        Taskinator.redis do |conn|
          conn.hset(subject.process_key, :options, YAML.dump({:foo => :bar}))
        end

        expect(subject.process_options).to eq(:foo => :bar)
      }
    end

    describe "#cleanup" do

      [
        TestDefinitions::Task,
        TestDefinitions::Job,
        TestDefinitions::SubProcess,
        TestDefinitions::Sequential,
        TestDefinitions::Concurrent,
        TestDefinitions::EmptySequentialProcessTest,
        TestDefinitions::EmptyConcurrentProcessTest,
        TestDefinitions::NestedTask,
      ].each do |definition|

        describe "#{definition.name} expire immediately" do
          it {
            Taskinator.redis do |conn|
              # sanity check
              expect(conn.keys).to be_empty

              process = definition.create_process(1)

              # sanity check
              expect(conn.hget(process.key, :uuid)).to eq(process.uuid)

              process.cleanup(0) # immediately

              # ensure nothing left behind
              expect(conn.keys).to be_empty
            end
          }
        end

      end

      describe "expires in future" do
        it {
          Taskinator.redis do |conn|

            # sanity check
            expect(conn.keys).to be_empty

            process = TestDefinitions::Task.create_process(1)

            # sanity check
            expect(conn.hget(process.key, :uuid)).to eq(process.uuid)

            process.cleanup(2)

            # still available...
            expect(conn.hget(process.key, :uuid)).to_not be_nil
            recursively_enumerate_tasks(process.tasks) do |task|
              expect(conn.hget(task.key, :uuid)).to_not be_nil
            end

            sleep 3

            # ensure nothing left behind
            expect(conn.keys).to be_empty
          end
        }
      end

    end
  end
end
