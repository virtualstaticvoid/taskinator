require 'spec_helper'

describe Taskinator do
  subject { Taskinator }

  describe "#options" do
    it { expect(subject.options).to be_a(Hash) }
    it {
      options = { :a => 1, :b => 2 }
      subject.options = options
      expect(subject.options).to eq(options)
    }
  end

  describe "#configure" do
    it "yields to block" do
      block = SpecSupport::Block.new
      expect(block).to receive(:call).with(subject)
      subject.configure(&block)
    end
  end

  describe "#redis" do
    it "yields to block" do
      block = SpecSupport::Block.new
      expect(block).to receive(:call)
      subject.redis(&block)
    end

    it "raise error when no block" do
      expect {
        subject.redis
      }.to raise_error(ArgumentError)
    end
  end

  describe "#redis_pool" do
    it { expect(subject.redis_pool).to_not be_nil }
  end

  describe "#queue_config" do
    it {
      subject.queue_config = {:a => 1}
      expect(subject.queue_config).to eq({:a => 1})
    }
  end

  describe "#logger" do
    it { expect(subject.logger).to_not be_nil }
    it {
      logger = Logger.new(File::NULL)
      subject.logger = logger
      expect(subject.logger).to eq(logger)
      subject.logger = nil
    }
  end

  describe "#instrumenter" do
    it { expect(subject.instrumenter).to_not be_nil }

    it {
      orig_instrumenter = subject.instrumenter

      instrumenter = Class.new().new
      subject.instrumenter = instrumenter
      expect(subject.instrumenter).to eq(instrumenter)

      subject.instrumenter = orig_instrumenter
    }

    it "yields to given block" do
      block = SpecSupport::Block.new
      expect(block).to receive(:call)

      subject.instrumenter.instrument(:foo, :bar => :baz, &block)
    end

    it "instruments event, when activesupport is referenced" do
      block = SpecSupport::Block.new
      expect(block).to receive(:call)

      # temporary subscription
      ActiveSupport::Notifications.subscribed(block, /.*/) do
        subject.instrumenter.instrument(:foo, :bar) do
          :baz
        end
      end
    end
  end

  [
    Taskinator::NoOpInstrumenter,
    Taskinator::ConsoleInstrumenter
  ].each do |instrumenter|
    describe instrumenter do
      it "yields to given block" do
        instance = instrumenter.new

        block = SpecSupport::Block.new
        expect(block).to receive(:call)

        instance.instrument(:foo, :bar => :baz, &block)
      end
    end
  end

end
