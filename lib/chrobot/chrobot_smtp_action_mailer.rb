module Chrobot
  
  module ChrobotSmtpActionMailer
    
    private
    
    def perform_delivery_chrobot_smtp(mail)
      # copied and changed from Rails 2.2.2, ActionMailer::Base
      destinations = mail.destinations
      mail.ready_to_send
      sender = mail['return-path'] || mail.from

      SmtpAction.queue!(sender, destinations, mail.encoded)
    end
    
  end
  
end