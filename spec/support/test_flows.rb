module TestFlows

  module Worker
    def self.perform(*args)
    end

    def perform(*args)
    end
  end

  module Support

    def iterator(task_count)
      task_count.times do |i|
        yield i
      end
    end

    def do_task(*args)
    end

  end

  module Task
    extend Taskinator::Definition
    include Support

    define_process :task_count do
      for_each :iterator do
        task :do_task
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

end
