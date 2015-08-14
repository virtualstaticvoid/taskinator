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
      allow(subject).to receive(:instrumentation_payload).and_return(:foo => :bar)

      expect(Taskinator.instrumenter).to receive(:instrument).with(event, {:foo => :bar}).and_call_original

      block = SpecSupport::Block.new
      expect(block).to receive(:call)

      subject.instrument(event, &block)
    }

    it {
      event = 'foo_bar'
      allow(subject).to receive(:instrumentation_payload).with(:baz => :qux).and_return({})

      expect(Taskinator.instrumenter).to receive(:instrument).with(event, {}).and_call_original

      block = SpecSupport::Block.new
      expect(block).to receive(:call)

      subject.instrument(event, :baz => :qux, &block)
    }
  end

  describe "#instrumentation_payload" do
    it {
      time_now = Time.now.utc
      Taskinator.redis do |conn|
        conn.hset(subject.key, :process_uuid, subject.uuid)
        conn.hmset(
          subject.process_key,
          [:options, YAML.dump({:foo => :bar})],
          [:tasks_count, 100],
          [:completed, 3],
          [:cancelled, 2],
          [:failed, 1],
          [:created_at, time_now],
          [:updated_at, time_now]
        )
      end

      expect(subject.instrumentation_payload(:baz => :qux)).to eq({
        :type                  => subject.class.name,
        :process_uuid          => subject.uuid,
        :process_options       => {:foo => :bar},
        :uuid                  => subject.uuid,
        :percentage_failed     => 1.0,
        :percentage_cancelled  => 2.0,
        :percentage_completed  => 3.0,
        :tasks_count           => 100,
        :created_at            => time_now.to_s,
        :updated_at            => time_now.to_s,
        :baz                   => :qux
      })
    }

  end

end
