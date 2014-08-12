# Taskinator

[![Gem Version](https://badge.fury.io/rb/taskinator.svg)](http://badge.fury.io/rb/taskinator)
[![Build Status](https://secure.travis-ci.org/virtualstaticvoid/taskinator.png?branch=master)](http://travis-ci.org/virtualstaticvoid/taskinator)
[![Code Climate](https://codeclimate.com/github/virtualstaticvoid/taskinator.png)](https://codeclimate.com/github/virtualstaticvoid/taskinator)
[![Coverage Status](https://coveralls.io/repos/virtualstaticvoid/taskinator/badge.png)](https://coveralls.io/r/virtualstaticvoid/taskinator)
[![Dependency Status](https://gemnasium.com/virtualstaticvoid/taskinator.svg)](https://gemnasium.com/virtualstaticvoid/taskinator)

A simple orchestration library for running complex processes or workflows in Ruby. Processes are defined using a simple DSL, where the sequences and
tasks are defined. Processes can then queued for execution. Sequences can be sychronous or asynchronous, and the overall process can be monitored
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

_Note:_ `resque` or `sidekiq` is recommended since they use Redis as a backing store as well.

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

Define the process, using the `define_process` method.

```ruby
module MyProcess
  extend Taskinator::Definition

  # defines a process
  define_process do

  end
end
```

Specify the tasks with their corresponding implementation methods, that make up the process, using the `task` method and providing
a `name` and `method` to execute for the task.

```ruby
module MyProcess
  extend Taskinator::Definition

  define_process do
    task 'Step A', :first_work_step
    task 'Step B', :second_work_step
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
      task 'Step A1', :work_step_1
      task 'Step A2', :work_step_2
    end

    sequential do
      # thes tasks will be executed sequentially
      task 'Step B1', :work_step_3
      task 'Step B2', :work_step_4
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

You can define data driven tasks using the `for_each` method, which takes an iterator method as an argument.
The iterator method yields the items to produce a parameterized task for that item. Notice that the task method
takes a parameter in this case, which will be the item provided by the iterator.

```ruby
module MyProcess
  extend Taskinator::Definition

  define_process do
    for_each :yield_data_elements do
      task 'Data Element Step', :work_step
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
    sub_process 'Process A', MySubProcessA
    sub_process 'Process B', MySubProcessB
  end
end
```

Any combination or nesting of `task`, `sequential`, `concurrent` and `for_each` steps are possible. E.g.

```ruby
module MyProcess
  extend Taskinator::Definition

  define_process do
    for_each :data_elements do
      task '...', :work_step_begin

      concurrent do
        for_each :sub_data_elements do
          task '...', :work_step_all_at_once
        end
      end

      sub_process '...', MySubProcess

      sequential do
        for_each :sub_data_elements do
          task '...', :work_step_one_by_one
        end
      end

      task '...', :work_step_end
    end
  end

  # "task" and "iterator" methods omitted for brevity
end
```

In this example, the `work_step_begin` is executed, followed by the `work_step_all_at_once` steps which are executed concurrently, then
the sub process `MySubProcess` is created and executed, followed by the `work_step_one_by_one` tasks which are executed sequentially and
finally the `work_step_end` is executed.

### Execution

A process is executed by calling the generated `create_process` method on your "process" module.

```ruby
process = MyProcess.create_process
process.enqueue!
```

### Monitoring

To monitor the state of the processes, use the `Taskinator::Api::Processes` class. This is still a work in progress.

```ruby
processes = Taskinator::Api::Processes.new()
processes.each do |process|
  # => output the unique process identifier and current state
  puts [:process, process.uuid, process.current_state.name]

  process.tasks.each do |task|
    # => output the task name and current state
    puts [:task, task.name, task.current_state.name]
  end
end
```

## Configuration

### Redis

By default Taskinator assumes Redis is located at `localhost:6397`. This is fine for development, but for many production environments
you will need to poiint to an external Redis server. You may also what to use a namespace for the Redis keys.
NOTE: The configuration hash _must_ have symbolized keys.

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
E.g. On Heroku, with RedisGreen: set REDIS_PROVIDER=REDISGREEN_URL and Taskinator will use the value of the `REDISGREEN_URL`
environment variable when connecting to Redis.

You may also use the generic `REDIS_URL` which may be set to your own private Redis server.

The Redis configuration leverages the same setup as `sidekiq`. For advanced options, checkout the
[Sidekiq Advanced Options](https://github.com/mperham/sidekiq/wiki/Advanced-Options#complete-control) wiki for more information.

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

For other workflow solutions, checkout [Stonepath](https://github.com/bokmann/stonepath), the now deprecated
[ruote](https://github.com/jmettraux/ruote) gem and [workflow](https://github.com/geekq/workflow). Alternatively, for a robust
enterprise ready solution checkout the [AWS Flow Framework for Ruby](http://docs.aws.amazon.com/amazonswf/latest/awsrbflowguide/welcome.html).
