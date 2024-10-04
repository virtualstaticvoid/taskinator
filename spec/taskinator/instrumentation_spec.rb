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
        @definition = TestDefinitions::Definition
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

  describe "#payload_for" do
    [
            [   1,  100,       0,         0,        0,        0,       0 ],
            [   2,  100,      10,        10,        0,        0,      20 ],
            [   3,  100,      20,        30,        0,        0,      50 ],
            [   4,  100,      25,        40,        0,        0,      65 ],
            [   5,  100,       0,       100,        0,        0,     100 ],
            [   6,  100,       0,        90,        1,        0,      91 ],
    ].each do |(s, count, processing, completed, cancelled, failed, check)|

      it "scenario ##{s}" do
        Taskinator.redis do |conn|
          conn.hset(subject.key, :process_uuid, subject.uuid)
          conn.hmset(
            subject.process_key,
            [:options, YAML.dump({:foo => :bar})],
            [:tasks_count, count],
            [:tasks_processing, processing],
            [:tasks_completed, completed],
            [:tasks_cancelled, cancelled],
            [:tasks_failed, failed]
          )
        end

        # private method, so use "send"
        payload = subject.send(:payload_for, "baz", {:qux => :quuz})

        expect(payload.instance_eval {
          percentage_failed +
          percentage_cancelled +
          percentage_processing +
          percentage_completed
        }).to eq(check)

        expect(payload).to eq(
          OpenStruct.new({
            :type                   => subject.class.name,
            :definition             => subject.definition.name,
            :process_uuid           => subject.uuid,
            :process_options        => {:foo => :bar},
            :uuid                   => subject.uuid,
            :options                => subject.options,
            :state                  => "baz",
            :percentage_failed      => (failed     / count.to_f) * 100.0,
            :percentage_cancelled   => (cancelled  / count.to_f) * 100.0,
            :percentage_processing  => (processing / count.to_f) * 100.0,
            :percentage_completed   => (completed  / count.to_f) * 100.0,
            :qux                    => :quuz
          })
        )

      end
    end
  end

  describe "payloads per state" do
    let(:additional) { {:qux => :quuz} }

    def payload_for(state, moar={})
      OpenStruct.new({
          :type                  => subject.class.name,
          :definition            => subject.definition.name,
          :process_uuid          => subject.uuid,
          :process_options       => {:foo => :bar},
          :uuid                  => subject.uuid,
          :options               => subject.options,
          :state                 => state,
          :percentage_failed     => 40.0,
          :percentage_cancelled  => 30.0,
          :percentage_processing => 10.0,
          :percentage_completed  => 20.0,
      }.merge(additional).merge(moar))
    end

    before do
      Taskinator.redis do |conn|
        conn.hset(subject.key, :process_uuid, subject.uuid)
        conn.hmset(
          subject.process_key,
          [:options, YAML.dump({:foo => :bar})],
          [:tasks_count, 100],
          [:tasks_processing, 10],
          [:tasks_completed, 20],
          [:tasks_cancelled, 30],
          [:tasks_failed, 40]
        )
      end
    end

    describe "#enqueued_payload" do
      it {
        expect(subject.enqueued_payload(additional)).to eq(payload_for(:enqueued))
      }
    end

    describe "#processing_payload" do
      it {
        expect(subject.processing_payload(additional)).to eq(payload_for(:processing))
      }
    end

    describe "#paused_payload" do
      it {
        expect(subject.paused_payload(additional)).to eq(payload_for(:paused))
      }
    end

    describe "#resumed_payload" do
      it {
        expect(subject.resumed_payload(additional)).to eq(payload_for(:resumed))
      }
    end

    describe "#completed_payload" do
      it {
        expect(subject.completed_payload(additional)).to eq(payload_for(:completed))
      }
    end

    describe "#cancelled_payload" do
      it {
        expect(subject.cancelled_payload(additional)).to eq(payload_for(:cancelled))
      }
    end

    describe "#failed_payload" do
      it {
        err = StandardError.new
        expect(subject.failed_payload(err, additional)).to eq(
          payload_for(:failed, :exception => err.to_s, :backtrace => err.backtrace))
      }
    end
  end
end
