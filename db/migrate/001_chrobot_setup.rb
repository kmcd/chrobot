class ChrobotSetup < ActiveRecord::Migration
  
  def self.up
    create_table :chrobot_items do |t|
      t.datetime :created_on, :null => false
      t.integer :lock_version, :null => false, :default => 0
            
      t.column :status, 'TINYINT UNSIGNED', :null => false
      t.datetime :run_at, :null => false
      t.datetime :allocated_on
      t.datetime :started_on
      t.datetime :completed_on

      t.string :allocated_to, :limit => 32      
      t.string :status_message
            
      t.string :short_action_serialized, :limit => 255, :null => false
      t.column :long_action_serialized, 'MEDIUMTEXT'
      
      t.boolean :slow, :null => false
      
      t.integer :retry_count, :null => false
      t.integer :reschedule_count, :null => false
      
      t.text :failure_message
    end
  
    change_table :chrobot_items do |t|
      t.index [:allocated_to, :status]
      t.index [:status, :run_at]
    end
    
    execute 'CREATE INDEX index_chrobot_items_on_action ON chrobot_items(short_action_serialized(32))'
  end
  
  def self.down
    drop_table :chrobot_items
  end
  
end