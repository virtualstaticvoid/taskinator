module TestDefinitions

  module Worker
    def self.perform(*args)
      # nop
    end
  end

  class TestTaskFailed < StandardError
  end

  module Support

    def iterator(task_count, *args)
      task_count.times do |i|
        yield i, *args
      end
    end

    # generate task methods so it's easy to see which task
    # corresponds with each method when debugging specs
    20.times do |i|
      define_method "task#{i}" do |*args|
        Taskinator.logger.info(">>> Executing task #{__method__} [#{uuid}]...")
      end
    end

    def task_fail(*args)
      raise TestTaskFailed
    end

    def task_before_started(*args)
      Taskinator.logger.info(">>> Executing before started task #{__method__} [#{uuid}]...")
    end

    def task_after_completed(*args)
      Taskinator.logger.info(">>> Executing after completed task #{__method__} [#{uuid}]...")
    end

    def task_after_failed(*args)
      Taskinator.logger.info(">>> Executing after failed task #{__method__} [#{uuid}]...")
    end

  end

  module Definition
    extend Taskinator::Definition
    include Support

  end

  module Task
    extend Taskinator::Definition
    include Support

    define_process :task_count do
      for_each :iterator do
        task :task1, :queue => :foo
      end
    end

  end

  module TaskBeforeStarted
    extend Taskinator::Definition
    include Support

    define_process do
      before_started :task_before_started

      task :task1
    end
  end

  module TaskBeforeStartedSubProcess
    extend Taskinator::Definition
    include Support

    define_process do
      sub_process TaskBeforeStarted
    end

  end

  module TaskAfterCompleted
    extend Taskinator::Definition
    include Support

    define_process do
      task :task1

      after_completed :task_after_completed
    end

  end

  module TaskAfterCompletedSubProcess
    extend Taskinator::Definition
    include Support

    define_process do
      sub_process TaskAfterCompleted
    end

  end

  module TaskAfterFailed
    extend Taskinator::Definition
    include Support

    define_process do
      task :task_fail

      after_failed :task_after_failed
    end

  end

  module TaskAfterFailedSubProcess
    extend Taskinator::Definition
    include Support

    define_process do
      sub_process TaskAfterFailed
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
          task :task1
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
          task :task1
        end
      end
    end

  end

  module EmptySequentialProcessTest
    extend Taskinator::Definition
    include Support

    define_process do

      task :task0

      sequential do
        # NB: empty!
      end

      sequential do
        task :task1
      end

      task :task2

    end
  end

  module EmptyConcurrentProcessTest
    extend Taskinator::Definition
    include Support

    define_process do

      task :task0

      concurrent do
        # NB: empty!
      end

      concurrent do
        task :task1
      end

      task :task2

    end
  end

  module NestedTask
    extend Taskinator::Definition
    include Support

    define_process :task_count do
      task :task1

      concurrent do
        task :task2
        task :task3

        sequential do
          task :task4
          task :task5

          concurrent do
            task :task6
            task :task7

            sequential do
              task :task8
              task :task9

            end

            task :task10
          end

          task :task11
        end

        task :task12
      end

      task :task13
    end
  end

end
