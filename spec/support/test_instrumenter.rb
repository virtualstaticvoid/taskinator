class TestInstrumenter

  class << self

    def subscribe(callback, filter=nil, &block)

      # create test instrumenter instance
      instrumenter = TestInstrumenter.new do |name, payload|
        if filter
          callback.call(name, payload) if name =~ filter
        else
          callback.call(name, payload)
        end
      end

      # hook up this instrumenter in the context of the spec
      # (assuming called from RSpec binding)
      spec_binding = block.binding.eval('self')
      spec_binding.instance_exec do
        allow(Taskinator).to receive(:instrumenter).and_return(instrumenter)
      end

      yield
    end

  end

  attr_reader :callback

  def initialize(&block)
    @callback = block
  end

  def instrument(event, payload={})
    @callback.call(event, payload)
    yield(payload) if block_given?
  end

end
