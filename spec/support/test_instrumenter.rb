class TestInstrumenter

  attr_reader :callback

  def initialize(&block)
    @callback = block
  end

  def instrument(event, payload={})
    @callback.call(event, payload)
    yield(payload) if block_given?
  end

end
