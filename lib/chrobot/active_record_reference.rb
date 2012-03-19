module Chrobot
  
  class ActiveRecordReference
    
    def initialize(object)
      raise "not an ActiveRecord::Base: #{object.inspect}" unless object.kind_of?(ActiveRecord::Base)
      raise "#{object.inspect} has been modified!" if object.changed?
      
      @object = object
    end
    
    def inspect
      "ar(#{@object.class.name}, #{@object.id})"
    end
    
  end
  
end