module Taskinator
  class CreateProcessWorker

    attr_reader :definition
    attr_reader :uuid
    attr_reader :args

    def initialize(definition_name, uuid, args)

      # convert to the module
      @definition = constantize(definition_name)

      # this will be uuid of the created process
      @uuid = uuid

      # convert to the typed arguments
      @args = Taskinator::Persistence.deserialize(args)

    end

    def perform
      @definition._create_process_(false, *@args, :uuid => @uuid).enqueue!
    end

    private

    # :nocov:
    def constantize(camel_cased_word)

      # borrowed from activesupport/lib/active_support/inflector/methods.rb

      names = camel_cased_word.split('::')

      # Trigger a built-in NameError exception including the ill-formed constant in the message.
      Object.const_get(camel_cased_word) if names.empty?

      # Remove the first blank element in case of '::ClassName' notation.
      names.shift if names.size > 1 && names.first.empty?

      names.inject(Object) do |constant, name|
        if constant == Object
          constant.const_get(name)
        else
          candidate = constant.const_get(name)
          next candidate if constant.const_defined?(name, false)
          next candidate unless Object.const_defined?(name)

          # Go down the ancestors to check if it is owned directly. The check
          # stops when we reach Object or the end of ancestors tree.
          constant = constant.ancestors.inject do |const, ancestor|
            break const    if ancestor == Object
            break ancestor if ancestor.const_defined?(name, false)
            const
          end

          # owner is in Object, so raise
          constant.const_get(name, false)
        end
      end
    end

  end
end
