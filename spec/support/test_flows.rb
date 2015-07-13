module TestFlows

  module Worker
    def self.perform(*args)
    end

    def perform(*args)
    end
  end

  module OneTask
    extend Taskinator::Definition

    define_process do
      task :task1
    end

    def task1
    end

  end

  module OneJob
    extend Taskinator::Definition

    define_process do
      job Worker
    end

  end

  module OneSubProcess
    extend Taskinator::Definition

    define_process do
      sub_process OneTask
    end

  end

  module OneSequential
    extend Taskinator::Definition

    define_process do
      sequential do
        task :task1
        task :task1
        task :task1
      end
    end

    def task1
    end

  end

  module OneConcurrent
    extend Taskinator::Definition

    define_process do
      concurrent do
        task :task1
        task :task1
        task :task1
      end
    end

    def task1
    end

  end

end
