#
# Copyright (c) Mike Perham
#
# Sidekiq is an Open Source project licensed under the terms of
# the LGPLv3 license.  Please see <http://www.gnu.org/licenses/lgpl-3.0.html>
# for license text.
#
# Sidekiq Pro has a commercial-friendly license allowing private forks
# and modifications of Sidekiq.  Please see http://sidekiq.org/pro/ for
# more detail.  You can find the commercial license terms in COMM-LICENSE.
#

require 'connection_pool'
require 'redis'
require 'uri'

module Taskinator
  class RedisConnection
    class << self

      def create(options={})
        url = options[:url] || determine_redis_provider
        if url
          options[:url] = url
        end

        pool_size = options[:pool_size] || 5
        pool_timeout = options[:pool_timeout] || 1

        log_info(options)

        ConnectionPool.new(:timeout => pool_timeout, :size => pool_size) do
          build_client(options)
        end
      end

      private

      def build_client(options)
        namespace = options[:namespace]

        client = Redis.new client_opts(options)
        if namespace
          require 'redis/namespace'
          Redis::Namespace.new(namespace, :redis => client)
        else
          client
        end
      end

      def client_opts(options)
        opts = options.dup
        if opts[:namespace]
          opts.delete(:namespace)
        end

        if opts[:network_timeout]
          opts[:timeout] = opts[:network_timeout]
          opts.delete(:network_timeout)
        end

        opts[:driver] = opts[:driver] || 'ruby'

        opts
      end

      def log_info(options)
        # Don't log Redis AUTH password
        scrubbed_options = options.dup
        if scrubbed_options[:url] && (uri = URI.parse(scrubbed_options[:url])) && uri.password
          uri.password = "REDACTED"
          scrubbed_options[:url] = uri.to_s
        end
        Taskinator.logger.info("#{Taskinator::NAME} client with redis options #{scrubbed_options}")
      end

      def determine_redis_provider
        ENV[ENV['REDIS_PROVIDER'] || 'REDIS_URL']
      end

    end
  end
end
