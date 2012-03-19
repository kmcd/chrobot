module Chrobot
  
  class DeferredAction < Action
    
    def initialize(o, method_name, *args)
      super
      
      @object = o
      @method_name = method_name
      @args = args
    end
    
    def process
      @object.__send__(@method_name, *@args)
    end
    
    def slow?
      true
    end
    
    def serialized_class_name
      'ds'
    end
    
  end
  
end