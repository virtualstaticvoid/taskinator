require 'spec_helper'

describe Taskinator::Api, :redis => true do

  describe Taskinator::Api::Processes do

    it { expect(subject).to be_a(::Enumerable) }

    describe "#each" do
      it "does not enumerate when there aren't any processes" do
        block = SpecSupport::Block.new()
        expect(block).to_not receive(:call)
        subject.each(&block)
      end

      it "it enumerates processes" do
        allow_any_instance_of(Process).to receive(:fetch) {}

        Taskinator.redis do |conn|
          conn.multi do
            3.times {|i| conn.sadd("taskinator:#{Taskinator::Persistence.list_key}", i) }
          end
        end

        block = SpecSupport::Block.new()
        expect(block).to receive(:call).exactly(3).times

        subject.each(&block)
      end
    end

    describe "#size" do
      it { expect(subject.size).to eq(0) }

      it "yields the number of processes" do
        Taskinator.redis do |conn|
          conn.multi do
            3.times {|i| conn.sadd("taskinator:#{Taskinator::Persistence.list_key}", i) }
          end
        end

        expect(subject.size).to eq(3)
      end
    end
  end

end
