module Chrobot
  
  class SmtpAction < FastAction   # fast/slow?  who knows?
    
    def initialize(sender, destinations, message)
      super
      
      @sender = sender
      @destinations = destinations
      @message = message
    end
    
    def process
      # copied and changed from Rails 2.2.2, ActionMailer::Base
      smtp_settings = ActionMailer::Base.smtp_settings

      smtp = Net::SMTP.new(smtp_settings[:address], smtp_settings[:port])
      smtp.enable_starttls_auto if smtp.respond_to?(:enable_starttls_auto)
      smtp.start(smtp_settings[:domain], smtp_settings[:user_name], smtp_settings[:password], smtp_settings[:authentication]) do |smtp|
        smtp.sendmail(@message, @sender, @destinations)
      end
    end
    
  end
  
end