require 'spec_helper'

describe Taskinator::Persistence, :redis => true do

  let(:definition) { TestDefinition }

  describe "class methods" do
    subject {
      Class.new do
        include Taskinator::Persistence
      end
    }

    describe ".base_key" do
      it {
        expect {
          subject.base_key
        }.to raise_error(NotImplementedError)
      }
    end

    describe ".key_for" do
      before do
        allow(subject).to receive(:base_key) { 'base_key' }
      end

      it {
        expect(subject.key_for('uuid')).to match(/base_key/)
        expect(subject.key_for('uuid')).to match(/uuid/)
      }
    end

    describe ".state_for" do
      before do
        allow(subject).to receive(:base_key) { 'base_key' }
      end

      it {
        expect(subject.state_for('uuid')).to eq(:initial)
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

      describe "for processes" do
        let(:process) { TestProcess.new(definition) }

        it {
          process.save
          expect(TestProcess.fetch(process.uuid)).to eq(process)
        }
      end

      describe "for tasks" do
        let(:process) { TestProcess.new(definition) }
        let(:task) { TestTask.new(process) }

        it {
          process.tasks << task
          process.save
          expect(TestTask.fetch(task.uuid)).to eq(task)
          expect(TestTask.fetch(task.uuid).process).to eq(process)
        }
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
          expect(subject.serialize([MockModel.new])).to eq(YAML.dump([{:model_id => 1, :model_type => 'TypeX'}]))
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
          expect(subject.serialize({:foo => MockModel.new})).to eq(YAML.dump({:foo => {:model_id => 1, :model_type => 'TypeX'}}))
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
          expect(subject.serialize(MockModel.new)).to eq(YAML.dump({:model_id => 1, :model_type => 'TypeX'}))
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
          subject.deserialize(YAML.dump([MockModel.new]))
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
          subject.deserialize(YAML.dump({:foo => MockModel.new}))
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
          subject.deserialize(YAML.dump(MockModel.new))
        }
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
          @uuid = SecureRandom.uuid
        end
      end
      klass.new
    }

    describe "#key" do
      it {
        expect(subject.key).to match(/#{subject.uuid}/)
      }
    end

    describe "#save" do
      pending __FILE__
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

        Taskinator.redis do |conn|
          expect(conn.hget(subject.key, :error_type)).to eq('StandardError')
          expect(conn.hget(subject.key, :error_message)).to eq('a error')
          expect(conn.hget(subject.key, :error_backtrace)).to_not be_empty
        end
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
  end
end
