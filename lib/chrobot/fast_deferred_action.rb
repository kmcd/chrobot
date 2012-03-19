module Chrobot
  
  class FastDeferredAction < DeferredAction
    
    def slow?
      false
    end
    
    def serialized_class_name
      'df'
    end
    
  end
  
end