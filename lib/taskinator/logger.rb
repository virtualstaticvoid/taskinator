#
# Copyright (c) Mike Perham
#
# Sidekiq is an Open Source project licensed under the terms of
# the LGPLv3 license.  Please see <http://www.gnu.org/licenses/lgpl-3.0.html>
# for license text.
#
require 'time'
require 'logger'

# :nocov:
module Taskinator
  module Logging

    class Pretty < Logger::Formatter
      # Provide a call() method that returns the formatted message.
      def call(severity, time, program_name, message)
        "#{time.utc.iso8601} #{::Process.pid} TID-#{Thread.current.object_id.to_s(36)}#{context} #{severity}: #{message}\n"
      end

      def context
        ctx = Thread.current[:taskinator_context]
        ctx ? " #{ctx}" : ''
      end
    end

    class << self

      def initialize_logger(log_target = STDOUT)
        oldlogger = defined?(@logger) ? @logger : nil
        @logger = Logger.new(log_target)
        @logger.level = Logger::INFO
        @logger.formatter = Pretty.new
        oldlogger.close if oldlogger && !$TESTING # don't want to close testing's STDOUT logging
        @logger
      end

      def logger
        defined?(@logger) ? @logger : initialize_logger
      end

      def logger=(log)
        @logger = (log ? log : Logger.new('/dev/null'))
      end

    end
  end
end
