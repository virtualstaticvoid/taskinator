module Taskinator
  module Api
    class Processes
      include Enumerable

      attr_reader :scope

      def initialize(scope=:shared)
        @scope = scope
        @processes_list_key = Taskinator::Persistence.processes_list_key(scope)
      end

      def each(&block)
        return to_enum(__method__) unless block_given?

        identifiers = Taskinator.redis do |conn|
          conn.smembers(@processes_list_key)
        end

        instance_cache = {}
        identifiers.each do |identifier|
          yield Process.fetch(identifier, instance_cache)
        end
      end

      def size
        Taskinator.redis do |conn|
          conn.scard(@processes_list_key)
        end
      end
    end

    def self.find_process(identifier)
      Process.fetch(identifier)
    end

    def self.find_task(identifier)
      Task.fetch(identifier)
    end
  end
end
