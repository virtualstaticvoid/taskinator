require 'spec_helper'

describe Taskinator::Queues::TestQueueAdapter do

  # sanity check for the test adapter

  it_should_behave_like "a queue adapter", :test_queue, Taskinator::Queues::TestQueueAdapter

end
