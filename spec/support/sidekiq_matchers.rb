module RSpec
  module Sidekiq
    module Matchers

      #
      # original version here:
      #  https://github.com/philostler/rspec-sidekiq/blob/develop/lib/rspec/sidekiq/matchers/be_processed_in.rb
      #
      #  this matcher needs to read off the actual queue name used, from the job array
      #  instead of reading off the job classes configuration
      #

      def be_processed_in_x(expected_queue)
        BeProcessedInX.new expected_queue
      end

      class BeProcessedInX
        def initialize(expected_queue)
          @expected_queue = expected_queue
        end

        def description
          "be processed in the \"#{@expected_queue}\" queue"
        end

        def failure_message
          "expected #{@klass} to be processed in the \"#{@expected_queue}\" queue but got \"#{@actual}\""
        end

        # NOTE: expects only one job in the queue, so don't forget to clear down the fake queue before each spec
        def matches?(job)
          @klass = job.is_a?(Class) ? job : job.class
          entry = @klass.jobs.first
          entry && (entry['queue'] == @expected_queue.to_s)
        end

        def failure_message_when_negated
          "expected #{@klass} to not be processed in the \"#{@expected_queue}\" queue"
        end
      end
    end
  end
end
