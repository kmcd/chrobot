# Include hook code here

ActionMailer::Base.send(:include, Chrobot::ChrobotSmtpActionMailer)
ActiveRecord::Base.send(:include, Chrobot::ActiveRecordExtras::InstanceExtras)
ActiveRecord::Base.send(:extend, Chrobot::ActiveRecordExtras::ClassExtras)