module MockDefinition

  class << self
    def create(queue=nil)

      definition = Module.new do
        extend Taskinator::Definition

        define_process :foo_hash do
          # empty on purpose
        end
      end

      definition.queue = queue

      # create a constant, so that the mock definition isn't anonymous
      Object.const_set("Mock#{SecureRandom.hex(4)}Definition", definition)

    end
  end

end
