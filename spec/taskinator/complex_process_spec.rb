require 'spec_helper'

describe TestFlow, :redis => true do
  it "should persist and retrieve" do
    processA = TestFlow.create_process(:arg1, :arg2)

    processB = Taskinator::Process.fetch(processA.uuid)

    expect(processB.uuid).to eq(processA.uuid)
    expect(processB.definition).to eq(processA.definition)
    expect(processB.options).to eq(processA.options)

    expect(processB.tasks.count).to eq(processA.tasks.count)

    tasks = processA.tasks.zip(processB.tasks)

    tasks.each do |(taskB, taskA)|
      expect(taskA.process).to eq(taskB.process)
      expect(taskA.uuid).to eq(taskB.uuid)
      expect(taskA.options).to eq(taskB.options)
    end
  end
end
