module Chrobot
  
  class TransactionalAction < FastAction
    
    def internal_process(*args)
      ChrobotItem.transaction do
        super(*args)
      end
    end
    
    def retry_after_exception?
      true
    end
    
    def retry_after_interrupt?
      true
    end
    
    def retry_after_timeout?
      true
    end
    
    def interruptable?
      true
    end
    
  end
  
end