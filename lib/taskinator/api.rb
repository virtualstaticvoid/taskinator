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

        instance_cache = {}
        Taskinator.redis do |conn|
          uuids = conn.smembers(@processes_list_key)
          uuids.each do |uuid|
            yield Process.fetch(uuid, instance_cache)
          end
        end
      end

      def size
        Taskinator.redis do |conn|
          conn.scard(@processes_list_key)
        end
      end
    end
  end
end
