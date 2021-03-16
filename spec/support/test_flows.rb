module TestFlows

  module Worker
    def self.perform(*args)
      # nop
    end
  end

  module Support

    def iterator(task_count, *args)
      task_count.times do |i|
        yield i, *args
      end
    end

    def do_task(*args)
      Taskinator.logger.info(">>> Executing task do_task [#{uuid}]...")
    end

    # just create lots of these, so it's easy to see which task
    # corresponds with each method when debugging specs
    20.times do |i|
      define_method "task_#{i}" do |*args|
        Taskinator.logger.info(">>> Executing task #{__method__} [#{uuid}]...")
      end
    end

  end

  module Task
    extend Taskinator::Definition
    include Support

    define_process :task_count do
      for_each :iterator do
        task :do_task, :queue => :foo
      end
    end

  end

  module Job
    extend Taskinator::Definition
    include Support

    define_process :task_count do
      for_each :iterator do
        job Worker
      end
    end

  end

  module SubProcess
    extend Taskinator::Definition
    include Support

    define_process :task_count do
      sub_process Task
    end

  end

  module Sequential
    extend Taskinator::Definition
    include Support

    define_process :task_count do
      sequential do
        for_each :iterator do
          task :do_task
        end
      end
    end

  end

  module Concurrent
    extend Taskinator::Definition
    include Support

    define_process :task_count do
      concurrent do
        for_each :iterator do
          task :do_task
        end
      end
    end

  end

  module EmptySequentialProcessTest
    extend Taskinator::Definition
    include Support

    define_process do

      task :task_0

      sequential do
        # NB: empty!
      end

      sequential do
        task :task_1
      end

      task :task_2

    end
  end

  module EmptyConcurrentProcessTest
    extend Taskinator::Definition
    include Support

    define_process do

      task :task_0

      concurrent do
        # NB: empty!
      end

      concurrent do
        task :task_1
      end

      task :task_2

    end
  end

  module NestedTask
    extend Taskinator::Definition
    include Support

    define_process :task_count do
      task :task_1

      concurrent do
        task :task_2
        task :task_3

        sequential do
          task :task_4
          task :task_5

          concurrent do
            task :task_6
            task :task_7

            sequential do
              task :task_8
              task :task_9

            end

            task :task_10
          end

          task :task_11
        end

        task :task_12
      end

      task :task_13
    end
  end

end
