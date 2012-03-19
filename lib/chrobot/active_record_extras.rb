module Chrobot
  module ActiveRecordExtras    
    
    module InstanceExtras
    
      def async(speed = :slow)
        ObjectMethodDeferrer.new(self, speed == :fast)
      end
        
    end
  
    module ClassExtras
      
      def async_method(method_name, action_type = :slow)
        class_eval make_async_method_code(method_name, action_type)
      end
      
      def async_class_method(method_name, action_type = :slow)
        class_eval "class << self\n#{make_async_method_code(method_name, action_type)}\nend"
      end

      private
      
      def make_async_method_code(method_name, action_type)
        # method name code from alias_method_chain
        # Strip out punctuation on predicates or bang methods since
        # e.g. target?_without_feature is not a valid method name.
        aliased_target, punctuation = method_name.to_s.sub(/([?!=])$/, ''), $1
        with_method, without_method = "#{aliased_target}_with_async#{punctuation}", "#{aliased_target}_without_async#{punctuation}"
        
        action_class = (action_type == :fast ? 'FastDeferredAction' : 'DeferredAction')
        
        "def #{with_method}(*args)
          if $CHROBOT_DISABLE_ASYNC || args.first == ::Chrobot::Action::MAGIC_MARKER
            args.shift if args.first == ::Chrobot::Action::MAGIC_MARKER
            return #{without_method}(*args)
          end
          
          ::Chrobot::#{action_class}.queue!(self, :#{method_name}, ::Chrobot::Action::MAGIC_MARKER, *args)
        end
        
        alias_method_chain :#{method_name}, :async"
      end
      
    end

  end  
end