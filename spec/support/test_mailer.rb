class TestMailer
  class Message
    def deliver_now
    end
  end

  def welcome(*args)
    Message.new
  end
end
