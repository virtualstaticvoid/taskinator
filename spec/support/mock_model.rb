class MockModel

  attr_reader :model_id
  attr_reader :model_type

  def initialize
    @model_id = 1
    @model_type = 'TypeX'
  end

  def global_id
    { :model_id => model_id, :model_type => model_type }
  end

  def find
  end

end
