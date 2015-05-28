module MockDefinition

  class << self
    def create(queue=nil)

      definition = Module.new() do
        extend Taskinator::Definition

        define_process :foo_hash do
          # empty on purpose
        end
      end

      definition.queue = queue

      Object.const_set("Mock#{SecureRandom.hex}Definition", definition)

    end
  end

end
