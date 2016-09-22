require 'statsd'

module Taskinator
  module LogStats
    class << self

      def initialize_client
        @client = Statsd.new()
      end

      def client
        defined?(@client) ? @client : initialize_client
      end

      def client=(statsd_client)
        @client = (statsd_client ? statsd_client : initialize_client)
      end

      def duration(stat, duration)
        client.timing(stat, duration * 1000)
      end

      def timing(stat, &block)
        result = nil
        duration = Benchmark.realtime do
          result = yield
        end
        duration(stat, duration)
        result
      end

      def gauge(stat, count)
        client.gauge(stat, count)
      end

      def count(stat, count)
        client.count(stat, count)
      end

      def increment(stat)
        client.increment(stat)
      end

      def decrement(stat)
        client.decrement(stat)
      end
    end
  end
end
