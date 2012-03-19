module Chrobot
  
  class DummyAction < SlowAction
    
    # so we can test out args
    def initialize(slow, *args)
      super
      
      @slow = slow
    end

    def process
      raise "random failure" if [true, false].rand
      
      puts item.run_at
    end
     
    def slow?
      @slow
    end
       
  end
  
end