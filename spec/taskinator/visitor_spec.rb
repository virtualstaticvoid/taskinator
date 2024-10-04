require 'spec_helper'

describe "Visitors" do

  it_should_behave_like "a visitor", Taskinator::Visitor::Base
  it_should_behave_like "a visitor", Taskinator::Persistence::RedisSerializationVisitor
  it_should_behave_like "a visitor", Taskinator::Persistence::XmlSerializationVisitor
  it_should_behave_like "a visitor", Taskinator::Persistence::RedisDeserializationVisitor
  it_should_behave_like "a visitor", Taskinator::Persistence::RedisCleanupVisitor

end
