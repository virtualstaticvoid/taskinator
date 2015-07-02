module Taskinator
  class Tasks
    include Enumerable

    # implements a linked list, where each task references the next task

    attr_reader :head
    alias_method :first, :head

    def initialize(first=nil)
      @head = first
    end

    def add(task)
      if @head.nil?
        @head = task
      else
        current = @head
        while current.next
          current = current.next
        end
        current.next = task
      end
      task
    end

    alias_method :<<, :add
    alias_method :push, :add

    def empty?
      @head.nil?
    end

    def each
      return to_enum(__method__) unless block_given?

      current = @head
      while current
        yield current
        current = current.next
      end
    end

    def inspect
      %(#<#{self.class.name}:0x#{self.__id__.to_s(16)} tasks=[#{collect(&:inspect).join(', ')}]>)
    end

  end
end
