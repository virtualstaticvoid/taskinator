module TestFlow
  extend Taskinator::Definition

  define_process :some_arg1, :some_arg2 do

    task :test_task

    for_each :iterator do
      task :test_task
    end

    for_each :iterator, :sub_option => 1 do
      task :test_task
    end

    sequential do
      task :test_task
      task :test_task
      task :test_task
    end

    task :test_task

    concurrent do
      20.times do |i|
        task :test_task
      end
      task :test_task
    end

    task :test_task

    # invoke the specified sub process
    sub_process TestSubFlow

    job TestJob

    on_completed :test_task
    on_completed_job TestJob

    on_failed :test_task
    on_failed_job TestJob

  end

  # note: arg1 and arg2 are passed in all the way from the
  #  definition#create_process method
  def iterator(arg1, arg2, options={})
    3.times do |i|
      yield [arg1, arg2, i, options]
    end
  end

  def test_task(*args)
    Taskinator.logger.info "Executing task with [#{args}]..."
  end

  module TestSubFlow
    extend Taskinator::Definition

    define_process :some_arg1, :some_arg2 do

      task :test_task
      task :test_task
      task :test_task

      on_completed :test_task
      on_completed_job TestJob

      on_failed :test_task
      on_failed_job TestJob

    end

    def test_task(*args)
      Taskinator.logger.info "Executing sub task with [#{args}]..."
    end
  end

  module TestJob
    def self.perform(*args)
      Taskinator.logger.info "Executing job with [#{args}]..."
    end

    def perform(*args)
      Taskinator.logger.info "Executing job with [#{args}]..."
    end
  end

end
