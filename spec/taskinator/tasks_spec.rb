require 'spec_helper'

describe Taskinator::Tasks do

  class Element
    attr_accessor :next
  end

  it { expect(subject).to be_a(::Enumerable) }

  it { expect(subject).to respond_to(:add) }
  it { expect(subject).to respond_to(:<<) }
  it { expect(subject).to respond_to(:push) }
  it { expect(subject).to respond_to(:each) }
  it { expect(subject).to respond_to(:empty?) }
  it { expect(subject).to respond_to(:head) }

  describe "#initialize" do
    it "starts with nil head" do
      first = double()
      instance = Taskinator::Tasks.new
      expect(instance.head).to be_nil
    end

    it "assigns head to first element" do
      first = double()
      instance = Taskinator::Tasks.new(first)
      expect(instance.head).to eq(first)
    end
  end

  describe "#add" do
    it "assigns to head for first element" do
      first = Element.new
      instance = Taskinator::Tasks.new
      instance.add(first)
      expect(instance.head).to eq(first)
    end

    it "links first element to the second element" do
      first = Element.new
      second = Element.new

      expect(first).to receive(:next=).with(second)

      instance = Taskinator::Tasks.new(first)
      instance.add(second)
    end

    it "links second element to the third element" do
      first = Element.new
      second = Element.new
      third = Element.new

      expect(second).to receive(:next=).with(third)

      instance = Taskinator::Tasks.new(first)
      instance.add(second)
      instance.add(third)
    end
  end

  describe "#each" do
    it "yields enumerator if no block given" do
      block = SpecSupport::Block.new
      expect(block).to receive(:call).exactly(3).times

      instance = Taskinator::Tasks.new
      3.times { instance.add(Element.new) }

      enumerator = instance.each

      enumerator.each(&block)
    end

    it "enumerates elements" do
      block = SpecSupport::Block.new
      expect(block).to receive(:call).exactly(3).times

      instance = Taskinator::Tasks.new
      3.times { instance.add(Element.new) }

      instance.each(&block)
    end

    it "does not enumerate when empty" do
      block = SpecSupport::Block.new
      expect(block).to_not receive(:call)

      instance = Taskinator::Tasks.new

      instance.each(&block)
    end
  end

  describe "#empty?" do
    it { expect(Taskinator::Tasks.new.empty?).to be }
    it { expect(Taskinator::Tasks.new(Element.new).empty?).to_not be }
  end

end
