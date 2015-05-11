module Taskinator
  module Api
    class Processes
      include Enumerable

      def each(&block)
        instance_cache = {}
        Taskinator.redis do |conn|
          uuids = conn.smembers("taskinator:processes")
          uuids.each do |uuid|
            yield Process.fetch(uuid, instance_cache)
          end
        end
      end

      def size
        Taskinator.redis do |conn|
          conn.scard("taskinator:processes")
        end
      end
    end
  end
end
