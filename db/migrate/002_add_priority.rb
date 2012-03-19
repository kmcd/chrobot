class AddPriority < ActiveRecord::Migration
  
  def self.up
    add_column :chrobot_items, :priority, 'TINYINT UNSIGNED', :null => false

    ChrobotItem.update_all("priority = 100") # 100 is normal

    change_table :chrobot_items do |t|
      t.remove_index :column => [:status, :run_at]
      t.index [:priority, :status, :run_at]
    end
  end
  
  def self.down

    change_table :chrobot_items do |t|
      t.remove_index [:priority, :status, :run_at]
      t.index :column => [:status, :run_at]
    end
    remove_column :chrobot_items, :priority
  end
  
end