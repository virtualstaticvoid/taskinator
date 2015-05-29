require 'spec_helper'

describe Taskinator::CreateProcessWorker do

  let(:definition) { MockDefinition.create }
  let(:uuid) { SecureRandom.uuid }
  let(:args) { {:foo => :bar} }

  subject { Taskinator::CreateProcessWorker.new(definition.name, uuid, Taskinator::Persistence.serialize(:foo => :bar)) }

  describe "#initialize" do
    it {
      expect(subject.definition).to eq(definition)
    }

    it {
      expect(subject.uuid).to eq(uuid)
    }

    it {
      expect(subject.args).to eq(args)
    }
  end

  describe "#perform" do
    it "should create the process" do
      expect(definition).to receive(:create_process).with(*args, :uuid => uuid).and_return(double('process', :enqueue! => nil))
      subject.perform
    end

    it "should enqueue the process" do
      expect_any_instance_of(Taskinator::Process).to receive(:enqueue!)
      subject.perform
    end
  end


end
