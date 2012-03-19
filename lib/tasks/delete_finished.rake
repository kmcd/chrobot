namespace :chrobot do

  desc "Deletes all successfully finished items that are a day old"
  task :delete_finished => :environment do
    ChrobotItem.delete_all(["status = ? AND completed_on < ? ", ChrobotItem::FINISHED, Time.now.utc - 1.days])
  end
  
end