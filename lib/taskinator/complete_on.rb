module Taskinator
  module CompleteOn

    # task completion options for concurrent processes

    # completes after the fastest task is completed
    # subsequent tasks continue to execute
    First = 10

    # completes once all tasks are completed
    Last = 20

    # for convenience, the default option
    Default = Last

  end
end
