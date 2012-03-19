module Chrobot
  
  class ObjectMethodDeferrer
    
    (instance_methods - %w(inspect method_missing __send__ __id__ clone)).each do |method|
      undef_method method
    end

    def initialize(object, fast)
      @object = object
      @fast = fast
    end
    
    def method_missing(method_name, *args)
      raise "you can't Chrobot defer a block method" if block_given?
      raise "can't async an async!" if method_name.to_s == 'async'
      
      super unless @object.respond_to?(method_name)
      
      (@fast ? FastDeferredAction : DeferredAction).queue!(@object, method_name, *args)
    end
    
  end
  
end