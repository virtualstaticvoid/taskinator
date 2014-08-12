module TestFlow
  extend Taskinator::Definition

  define_process do
    task '~', :error_task, :continue_on_error => true

    task 'A', :the_task

    for_each 'Items', :iterator do
      task 'B', :the_task
    end

    sequential 'C' do
      task 'C1', :the_task
      task 'C2', :the_task
      task 'C3', :the_task
    end

    task 'D', :the_task

    concurrent 'E' do
      20.times do |i|
        task "E#{i+1}", :the_task
      end
      task 'Ennnn', :the_task
    end

    task 'F', :the_task

    # invoke the specified sub process
    sub_process 'G', TestSubFlow
  end

  def error_task(*args)
    raise "It's a huge problem!"
  end

  # note: arg1 and arg2 are passed in all the way from the
  #  definition#create_process method
  def iterator(arg1, arg2)
    3.times do |i|
      yield [arg1, arg2, i]
    end
  end

  def the_task(*args)
    t = rand(1..11)
    Taskinator.logger.info "Executing task '#{task}' with [#{args}] for #{t} secs..."
    sleep 1 # 1
  end

  module TestSubFlow
    extend Taskinator::Definition

    define_process do
      task 'SubA', :the_task
      task 'SubB', :the_task
      task 'SubC', :the_task
    end

    def the_task(*args)
      t = rand(1..11)
      Taskinator.logger.info "Executing sub task '#{task}' with [#{args}] for #{t} secs..."
      sleep 1 # t
    end
  end

end
