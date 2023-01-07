module TestJob
  def self.perform(*args)
  end
end

class TestJobClass
  def perform(*args)
  end
end

module TestJobModule
  def self.perform(*args)
  end
end

class TestJobClassNoArgs
  def perform
  end
end

module TestJobModuleNoArgs
  def self.perform
  end
end

module TestJobError
  def self.perform
    raise ArgumentError
  end
end
