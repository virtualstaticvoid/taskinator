module Taskinator
  class Tasks
    include Enumerable

    # implements a linked list, where each task references the next task

    attr_reader :head
    alias_method :first, :head

    attr_reader :count
    alias_method :length, :count

    def initialize(first=nil)
      @count = 0
      add(first) if first
    end

    def attach(task, count)
      @head = task
      @count = count
      task
    end

    def add(task)
      if @head.nil?
        @head = task
        @count = 1
      else
        current = @head
        while current.next
          current = current.next
        end
        current.next = task
        @count += 1
      end
      task
    end

    alias_method :<<, :add
    alias_method :push, :add

    def empty?
      @head.nil?
    end

    def each(&block)
      return to_enum(__method__) unless block_given?

      current = @head
      while current
        yield current
        current = current.next
      end
    end

    def inspect
      %([#{collect(&:inspect).join(', ')}])
    end

  end
end
