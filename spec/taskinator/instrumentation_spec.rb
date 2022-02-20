require 'spec_helper'

describe Taskinator::Instrumentation, :redis => true do

  subject do
    klass = Class.new do
      include Taskinator::Persistence
      include Taskinator::Instrumentation

      def self.base_key
        'base_key'
      end

      attr_reader :uuid
      attr_reader :options
      attr_reader :definition

      def initialize
        @uuid = Taskinator.generate_uuid
        @options = { :bar => :baz }
        @definition = TestDefinition
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
    pending
  end

  describe "#processing_payload" do
    pending
  end

  describe "#completed_payload" do
    it {
      Taskinator.redis do |conn|
        conn.hset(subject.key, :process_uuid, subject.uuid)
        conn.hmset(
          subject.process_key,
          [:options, YAML.dump({:foo => :bar})],
          [:tasks_count, 100],
          [:tasks_processing, 1],
          [:tasks_completed, 2],
          [:tasks_cancelled, 3],
          [:tasks_failed, 4]
        )
      end

      expect(subject.completed_payload(:baz => :qux)).to eq(
        OpenStruct.new({
          :type                   => subject.class.name,
          :definition             => subject.definition.name,
          :process_uuid           => subject.uuid,
          :process_options        => {:foo => :bar},
          :uuid                   => subject.uuid,
          :state                  => :completed,
          :options                => subject.options,
          :percentage_processing  => 1.0,
          :percentage_completed   => 2.0,
          :percentage_cancelled   => 3.0,
          :percentage_failed      => 4.0,
          :baz                    => :qux
        })
      )
    }
  end

  describe "#cancelled_payload" do
    pending
  end

  describe "#failed_payload" do
    pending
  end

end
