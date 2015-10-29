require 'spec_helper'

describe Taskinator::CreateProcessWorker do

  let(:definition) { MockDefinition.create }
  let(:uuid) { Taskinator.generate_uuid }
  let(:args) { [{:foo => :bar}] }

  subject { Taskinator::CreateProcessWorker.new(definition.name, uuid, Taskinator::Persistence.serialize(args)) }

  describe "#initialize" do
    it {
      expect(subject.definition).to eq(definition)
    }

    it {
      Taskinator::CreateProcessWorker.new(definition.name, uuid, Taskinator::Persistence.serialize(args))
      expect(subject.definition).to eq(definition)
    }

    it {
      MockDefinition.const_set(definition.name, definition)
      Taskinator::CreateProcessWorker.new("MockDefinition::#{definition.name}", uuid, Taskinator::Persistence.serialize(args))
      expect(subject.definition).to eq(definition)
    }

    it {
      expect {
        Taskinator::CreateProcessWorker.new("NonExistent", uuid, Taskinator::Persistence.serialize(args))
      }.to raise_error(NameError)
    }

    it {
      expect(subject.uuid).to eq(uuid)
    }

    it {
      expect(subject.args).to eq(args)
    }
  end

  describe "#perform" do
    describe "create the process" do
      it "with no arguments" do
        process_args = [{:uuid => uuid}]
        args = Taskinator::Persistence.serialize([])

        expect(definition).to receive(:_create_process_).with(false, *process_args).and_return(double('process', :enqueue! => nil))

        Taskinator::CreateProcessWorker.new(definition.name, uuid, args).perform
      end

      it "with arguments" do
        process_args = [:foo, :bar, {:uuid => uuid}]
        serialized_args = Taskinator::Persistence.serialize([:foo, :bar])

        expect(definition).to receive(:_create_process_).with(false, *process_args).and_return(double('process', :enqueue! => nil))

        Taskinator::CreateProcessWorker.new(definition.name, uuid, serialized_args).perform
      end

      it "with options" do
        process_args = [{:foo => :bar, :uuid => uuid}]
        serialized_args = Taskinator::Persistence.serialize([{:foo => :bar}])

        expect(definition).to receive(:_create_process_).with(false, *process_args).and_return(double('process', :enqueue! => nil))

        Taskinator::CreateProcessWorker.new(definition.name, uuid, serialized_args).perform
      end

      it "with arguments and options" do
        process_args = [:foo, {:bar => :baz, :uuid => uuid}]
        serialized_args = Taskinator::Persistence.serialize([:foo, {:bar => :baz}])

        expect(definition).to receive(:_create_process_).with(false, *process_args).and_return(double('process', :enqueue! => nil))

        Taskinator::CreateProcessWorker.new(definition.name, uuid, serialized_args).perform
      end
    end

    it "should enqueue the process" do
      expect_any_instance_of(Taskinator::Process).to receive(:enqueue!)
      subject.perform
    end
  end
end
