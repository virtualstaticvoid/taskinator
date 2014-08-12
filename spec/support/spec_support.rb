module SpecSupport
  class Block
    def to_proc
      lambda { |*args| call(*args) }
    end

    # the call method must be provided by in specs
    # E.g. using `expect(mock_block_instance).to receive(:call)` to assert that the "block" gets called
    def call
      raise NotImplementedError, "Expecting `call` method to have an expectation defined to assert."
    end
  end
end
