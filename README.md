# Taskinator

[![Gem Version](https://badge.fury.io/rb/taskinator.svg)](http://badge.fury.io/rb/taskinator)
[![Build Status](https://secure.travis-ci.org/virtualstaticvoid/taskinator.png?branch=master)](http://travis-ci.org/virtualstaticvoid/taskinator)
[![Code Climate](https://codeclimate.com/github/virtualstaticvoid/taskinator.png)](https://codeclimate.com/github/virtualstaticvoid/taskinator)
[![Coverage Status](https://coveralls.io/repos/virtualstaticvoid/taskinator/badge.png)](https://coveralls.io/r/virtualstaticvoid/taskinator)

A simple orchestration library for running complex processes or workflows in Ruby. Processes are defined using a simple DSL, where the sequences and
tasks are defined. Processes can then be queued for execution. Sequences can be synchronous or asynchronous, and the overall process can be monitored
for completion or failure.

Processes and tasks are executed by background workers and you can use any one of the following gems:

* [resque](https://github.com/resque/resque)
* [sidekiq](https://github.com/mperham/sidekiq)
* [delayed_job](https://github.com/collectiveidea/delayed_job)

The configuration and state of each process and their respective tasks is stored using Redis key/values.

## Requirements

The latest MRI (2.1, 2.0) version. Other versions/VMs are untested but might work fine. MRI 1.9 is not supported.

Redis 2.4 or greater is required.

One of the following background worker queue gems: `resque`, `sidekiq` or `delayed_job`.

_NOTE:_ `resque` or `sidekiq` is recommended since they use Redis as a backing store as well.

## Installation

Add this line to your application's Gemfile:

    gem 'taskinator'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install taskinator

## Usage

### Definition

Start by creating a "process" module and extending `Taskinator::Definition`.

```ruby
require 'taskinator'
module MyProcess
  extend Taskinator::Definition

end
```

Define the process using the `define_process` method.

```ruby
module MyProcess
  extend Taskinator::Definition

  # defines a process
  define_process do

  end
end
```

The `define_process` method optionally takes the list of expected arguments which are used to validate the arguments supplied when creating a new process.
These should be specified with symbols.

```ruby
module MyProcess
  extend Taskinator::Definition

  # defines a process
  define_process :date, :options do
    # ...
  end
end

# when creating a process, 2 arguments are expected
process = MyProcess.create_process Date.today, :option_1 => true
```

_NOTE:_ The current implementation performs a naive check on the count of arguments.

Next, specify the tasks with their corresponding implementation methods, that make up the process, using the `task` method and providing the `method` to execute for the task.

```ruby
module MyProcess
  extend Taskinator::Definition

  define_process do
    task :first_work_step
    task :second_work_step
  end

  def first_work_step
    # TODO: supply implementation
  end

  def second_work_step
    # TODO: supply implementation
  end
end
```

More complex processes may define sequential or concurrent steps, using the `sequential` and `concurrent` methods respectively.

```ruby
module MyProcess
  extend Taskinator::Definition

  define_process do
    concurrent do
      # these tasks will be executed concurrently
      task :work_step_1
      task :work_step_2
    end

    sequential do
      # thes tasks will be executed sequentially
      task :work_step_3
      task :work_step_4
    end
  end

  def work_step_1
    # TODO: supply implementation
  end

  ...

  def work_step_N
    # TODO: supply implementation
  end

end
```

It is likely that you already have worker classes for one of the queueing libraries, such as resque or delayed_job, and wish to reuse them for executing them in the sequence defined by the process definition.

Define a `job` step, providing the class of the worker, and then taskinator will execute that worker as part of the process definition.
The `job` step will be queued and executed on same queue as configured by `delayed_job`, or that of the worker for `resque` and `sidekiq`.

```ruby
# E.g. A resque worker
class DoSomeWork
  queue :high_priority

  def self.perform(arg1, arg2)
    # code to do the work
  end
end

module MyProcess
  extend Taskinator::Definition

  # when creating the process, supply the same arguments
  # that the DoSomeWork worker expects

  define_process do
    job DoSomeWork
  end
end
```

You can also define data driven tasks using the `for_each` method, which takes an iterator method name as an argument.
The iterator method yields the parameters necessary for the task or job. Notice that the task method takes a parameter in this case, which will be the return values provided by the iterator.

```ruby
module MyProcess
  extend Taskinator::Definition

  define_process do
    for_each :yield_data_elements do
      task :work_step
    end
  end

  def yield_data_elements
    # TODO: supply implementation to yield elements
    yield 1
  end

  def work_step(data_element)
    # TODO: supply implementation
  end
end
```

It is possible to branch the process logic based on the options hash passed in when creating a process.
The `options?` method takes the options key as an argument and calls the supplied block if the option is present and it's value is truthy.

```ruby
module MyProcess
  extend Taskinator::Definition

  define_process do

    option?(:some_setting) do
      task :prerequisite_step
    end

    task :work_step

  end

  def prerequisite_step
    # ...
  end

  def work_step
    # ...
  end

end

# now when creating the process, the `:some_setting` option can be used to branch the logic
process1 = MyProcess.create_process :some_setting => true
process1.tasks.count #=> 2

process2 = MyProcess.create_process
process2.tasks.count #=> 1
```

In addition, it is possible to transform the arguments used by a task or job, by including a `transform` step in the definition.
Similarly for the `for_each` method, `transform` takes a method name as an argument. The transformer method must yield the new arguments as required.

```ruby
module MyProcess
  extend Taskinator::Definition

  # this process is created with a hash argument

  define_process do
    transform :convert_args do
      task :work_step
    end
  end

  def convert_args(options)
    yield *[options[:date_from], options[:date_to]]
  end

  def work_step(date_from, date_to)
    # TODO: supply implementation
  end
end
```

Processes can be composed of other processes too:

```ruby
module MySubProcessA
  ...
end

module MySubProcessB
  ...
end

module MyProcess
  extend Taskinator::Definition

  define_process do
    sub_process MySubProcessA
    sub_process MySubProcessB
  end
end
```

Any combination or nesting of `task`, `sequential`, `concurrent` and `for_each` steps are possible. E.g.

```ruby
module MyProcess
  extend Taskinator::Definition

  define_process do
    for_each :data_elements do
      task :work_step_begin

      concurrent do
        for_each :sub_data_elements do
          task :work_step_all_at_once
        end
      end

      sub_process MySubProcess

      sequential do
        for_each :sub_data_elements do
          task :work_step_one_by_one
        end
      end

      task :work_step_end
    end
  end

  # "task" and "iterator" methods omitted for brevity

end
```

In this example, the `work_step_begin` is executed, followed by the `work_step_all_at_once` steps which are executed concurrently, then
the sub process `MySubProcess` is created and executed, followed by the `work_step_one_by_one` tasks which are executed sequentially and
finally the `work_step_end` is executed.

It is also possible to embed conditional logic within the process definition stages in order to produce steps based on the required logic.
All builder methods are available within the scope of the `define_process` block. These methods include `args` and `options`
which are passed into the `create_process` method of the definition.

E.g.

```ruby
module MyProcess
  extend Taskinator::Definition

  define_process do
    task :task_1
    task :task_2
    task :task_3 if args[3] == 1
    task :send_notification if options[:send_notification]
  end

  # "task" methods are omitted for brevity

end

# when creating this proces, you supply to option when calling `create_process`
# in this example, 'args' will be an array [1,2,3] and options will be a Hash {:send_notification => true}
MyProcess.create_process(1, 2, 3, :send_notification => true)

```

### Execution

A process is executed by calling the generated `create_process` method on your "process" module.

```ruby
process = MyProcess.create_process
process.enqueue!
```

Or, to start immediately, call the `start!` method.

```ruby
process = MyProcess.create_process
process.start!
```

#### Arguments

Argument handling for defining and executing process definitions is where things can get trickey.
_This may be something that gets refactored down the line_.

To best understand how arguments are handled, you need to break it down into 3 phases. Namely:

  * Definition,
  * Creation and
  * Execution

Firstly, a process definition is declarative in that the `define_process` and a mix of `sequential`, `concurrent`, `for_each`, `task` and `job` directives provide the way to specify the sequencing of the steps for the process.
Taskinator will interprete this definition and execute each step in the desired sequence or concurrency.

Consider the following process definition:

```ruby
module MySimpleProcess
  extend Taskinator::Definition

  # definition

  define_process do
    task :work_step_1
    task :work_step_2

    for_each :additional_step do
      task :work_step_3
    end
  end

  # creation

  def additional_step(options)
    options.steps.each do |k, v|
      yield k, v
    end
  end

  # execution

  def work_step_1(options)
    # ...
  end

  def work_step_2(options)
    # ...
  end

  def work_step_3(k, v)
    # ...
  end

end
```

There are three tasks; namely `:work_step_1`, `:work_step_2` and `:work_step_3`.

The third task, `:work_step_3`, is built up using the `for_each` iterator, which means that the number of `:work_step_3` tasks will depend on how many times the `additional_step` iterator method yields to the definition.

This brings us to the creation part. When `create_process` is called on the given module, you provide arguments to it, which will get passed onto the respective `task` and `for_each` iterator methods.

So, considering the `MySimpleProcess` module shown above, `work_step_1`, `work_step_2` and `work_step_3` methods each expect arguments.
These will ultimately come from the arguments passed into the `create_process` method.

E.g.

```ruby

# Given an options hash
options = {
  :opt1 => true,
  :opt2 => false,
  :steps => {
    :a => 1,
    :b => 2,
    :c => 3,
  }
}

# You create the process, passing in the options hash
process = MySimpleProcess.create_process(options)

```

To best understand how the process is created, consider the following "procedural" code for how it could work.

```ruby
# A process, which maps the target and a list of steps
class Process
  attr_reader :target
  attr_reader :tasks

  def initialize(target)
    @target = target
    @tasks = []
  end
end

# A task, which maps the method to call and it's arguments
class Task
  attr_reader :method
  attr_reader :args

  def initialize(method, args)
    @method, @args = method, args
  end
end

# Your module, with the methods which do the actual work
module MySimpleProcess

  def self.work_step_1(options) ...
  def self.work_step_2(options) ...
  def self.work_step_3(k, v) ...

end

# Now, the creation phase of the definition
# create a process, providing the module

process = Process.new(MySimpleProcess)

# create the first and second tasks, providing the method
# for the task and it's arguments, which are the options defined above

process.tasks << Task.new(:work_step_1, options)
process.tasks << Task.new(:work_step_2, options)

# iterate over the steps hash in the options, and add the third step
# this time specify the key and value as the
# arguments for the work_step_3 method

options.steps.each do |k, v|
  process.tasks << Task.new(:work_step_3, [k, v])
end

# we now have a process with the tasks defined

process.tasks  #=> [<Task :method=>work_step_1, :args=>options, ...> ,
               #    <Task :method=>work_step_2, :args=>options, ...>,
               #    <Task :method=>work_step_3, :args=>[:a, 1], ...>,
               #    <Task :method=>work_step_3, :args=>[:b, 2], ...>,
               #    <Task :method=>work_step_3, :args=>[:c, 3], ...>]

```

Finally, for the execution phase, the process and tasks will act on the supplied module.

```ruby
# building out the "Process" class
class Process
  #...

  def execute
    tasks.each {|task| task.execute(target) )
  end
end

# and the "Task" class
class Task
  #...

  def execute(target)
    puts "Calling '#{method}' on '#{target.name}' with #{args.inspect}..."
    target.send(method, *args)
  end
end

# executing the process iterates over each task and
# the target modules method is called with the arguments

process.execute

# Calling 'work_step_1' on 'MySimpleProcess' with {:opt1 => true, :opt2 => false, ...}
# Calling 'work_step_2' on 'MySimpleProcess' with {:opt1 => true, :opt2 => false, ...}
# Calling 'work_step_3' on 'MySimpleProcess' with [:a, 1]
# Calling 'work_step_3' on 'MySimpleProcess' with [:b, 2]
# Calling 'work_step_3' on 'MySimpleProcess' with [:c, 3]

```

In reality, each task is executed by a worker process, possibly on another host, so the execution process isn't as simple, but this example should help you to understand conceptually how the process is executed, and how the arguments are propagated through.

### Monitoring

To monitor the state of the processes, use the `Taskinator::Api::Processes` class. This is still a work in progress.

```ruby
processes = Taskinator::Api::Processes.new
processes.each do |process|
  # => output the unique process identifier and current state
  puts [:process, process.uuid, process.current_state]
end
```

## Configuration

### Redis

By default Taskinator assumes Redis is located at `localhost:6397`. This is fine for development, but for many production environments you will need to point to an external Redis server. You may also what to use a namespace for the Redis keys.
_NOTE:_ The configuration hash _must_ have symbolized keys.

```ruby
Taskinator.configure do |config|
 config.redis = {
   :url => 'redis://redis.example.com:7372/12',
   :namespace => 'mynamespace'
 }
end
```

Or, alternatively, via an `ENV` variable

Set the `REDIS_PROVIDER` environment variable to the Redis server url.
E.g. On Heroku, with RedisGreen: set REDIS_PROVIDER=REDISGREEN_URL and Taskinator will use the value of the `REDISGREEN_URL` environment variable when connecting to Redis.

You may also use the generic `REDIS_URL` which may be set to your own private Redis server.

The Redis configuration leverages the same setup as `sidekiq`. For advanced options, checkout the [Sidekiq Advanced Options](https://github.com/mperham/sidekiq/wiki/Advanced-Options#complete-control) wiki for more information.

### Queues

By default the queue names for process and task workers is `default`, however, you can specify the queue names as follows:

```ruby
Taskinator.configure do |config|
  config.queue_config = {
    :process_queue => :default,
    :task_queue => :default
  }
end
```

### Instrumentation

It is possible to instrument processes, tasks and jobs by providing an instrumeter such as `ActiveSupport::Notifications`.

```ruby
Taskinator.configure do |config|
  config.instrumenter = ActiveSupport::Notifications
end
```

Alternatively, you can use the built-in instrumenter for logging to the console for debugging:

```ruby
Taskinator.configure do |config|
  config.instrumenter = Taskinator::ConsoleInstrumenter.new
end
```

The following instrumentation events are issued:

| Event                              | When                                                      |
|------------------------------------|-----------------------------------------------------------|
| `taskinator.process.created`       | After a root process gets created                         |
| `taskinator.process.saved`         | After a root process has been persisted to Redis          |
| `taskinator.process.enqueued`      | After a process or subprocess is enqueued for processing  |
| `taskinator.process.processing`    | When a process or subprocess is processing                |
| `taskinator.process.paused`        | When a process or subprocess is paused                    |
| `taskinator.process.resumed`       | When a process or subprocess is resumed                   |
| `taskinator.process.completed`     | After a process or subprocess has completed processing    |
| `taskinator.process.cancelled`     | After a process or subprocess has been cancelled          |
| `taskinator.process.failed`        | After a process or subprocess has failed                  |
| `taskinator.task.enqueued`         | After a task has been enqueued                            |
| `taskinator.task.processing`       | When a task is processing                                 |
| `taskinator.task.completed`        | After a task has completed                                |
| `taskinator.task.cancelled`        | After a task has been cancelled                           |
| `taskinator.task.failed`           | After a task has failed                                   |

For all events, the data included contains the following information:

| Key                      | Value                                                 |
|--------------------------|-------------------------------------------------------|
| `:type`                  | The type name of the component reporting the event    |
| `:process_uuid`          | The UUID of the root process                          |
| `:process_options`       | Options hash of the root process                      |
| `:uuid`                  | The UUID of the respective task, job or sub process   |
| `:options`               | Options hash of the component                         |
| `:state`                 | State of the component                                |
| `:percentage_completed`  | The percentage of completed tasks                     |
| `:percentage_failed`     | The percentage of failed tasks                        |
| `:percentage_cancelled`  | The percentage of cancelled tasks                     |

## Notes

The persistence logic is decoupled from the implementation, so it is possible to implement another backing store if required.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License
MIT Copyright (c) 2014 Chris Stefano

Portions of code are from the Sidekiq project, Copyright (c) Contributed Systems LLC.

## Inspiration

Inspired by the [sidekiq](https://github.com/mperham/sidekiq) and [workflow](https://github.com/geekq/workflow) gems.

For other workflow solutions, checkout [Stonepath](https://github.com/bokmann/stonepath), the now deprecated [ruote](https://github.com/jmettraux/ruote) gem and [workflow](https://github.com/geekq/workflow). Alternatively, for a robust enterprise ready solution checkout the [AWS Flow Framework for Ruby](http://docs.aws.amazon.com/amazonswf/latest/awsrbflowguide/welcome.html).
