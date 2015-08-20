require 'spec_helper'

describe Taskinator::Instrumentation, :redis => true do

  let(:definition) { TestDefinition }

  subject do
    klass = Class.new do
      include Taskinator::Persistence
      include Taskinator::Instrumentation

      def self.base_key
        'base_key'
      end

      attr_reader :uuid

      def initialize
        @uuid = SecureRandom.uuid
      end
    end

    klass.new
  end

  describe "#instrument" do
    it {
      event = 'foo_bar'

      expect(Taskinator.instrumenter).to receive(:instrument).with(event, {}).and_call_original

      block = SpecSupport::Block.new
      expect(block).to receive(:call)

      subject.instrument(event, &block)
    }

    it {
      event = 'foo_bar'

      expect(Taskinator.instrumenter).to receive(:instrument).with(event, {:baz => :qux}).and_call_original

      block = SpecSupport::Block.new
      expect(block).to receive(:call)

      subject.instrument(event, :baz => :qux, &block)
    }
  end

  describe "#enqueued_payload" do
  end

  describe "#started_payload" do
  end

  describe "#completed_payload" do
    it {
      Taskinator.redis do |conn|
        conn.hset(subject.key, :process_uuid, subject.uuid)
        conn.hmset(
          subject.process_key,
          [:options, YAML.dump({:foo => :bar})],
          [:tasks_count, 100],
          [:completed, 3],
          [:cancelled, 2],
          [:failed, 1]
        )
      end

      expect(subject.completed_payload(:baz => :qux)).to eq({
        :type                  => subject.class.name,
        :process_uuid          => subject.uuid,
        :process_options       => {:foo => :bar},
        :uuid                  => subject.uuid,
        :state                 => :completed,
        :percentage_failed     => 1.0,
        :percentage_cancelled  => 2.0,
        :percentage_completed  => 3.0,
        :baz                   => :qux
      })
    }
  end

  describe "#cancelled_payload" do
  end

  describe "#failed_payload" do
  end

end
