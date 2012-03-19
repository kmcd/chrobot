module Chrobot
  
  class Action
    
    class MagicMarker
      def inspect
        'm'
      end
    end
    
    class ClassMarker
      def initialize(klass)
        @klass = klass
      end
      
      def inspect
        @klass.name
      end
    end
    
    MAGIC_MARKER = MagicMarker.new.freeze
    
    attr_reader :item
    
    def initialize(*spec)
      @spec = spec
    end
    
    def internal_process(timeout_seconds = nil)
      if timeout_seconds
        timeout(timeout_seconds, TimeoutException) { process }
      else
        process
      end
    end
    
    def process
      raise "not implemented"
    end
        
    def slow?
      raise "not implemented"
    end
    
    # should the action be retried if an exception occurs?
    def retry_after_exception?
      false
    end
    
    # should the action be retried if it times out?
    def retry_after_timeout?
      false
    end
    
    # if it gets killed by a SIGTERM or SIGINT, should it retry?
    def retry_after_interrupt?
      false
    end
    
    # should a SIGTERM or SIGINT stop this action running?
    def interruptable?
      false
    end

    def name
      self.class.name.gsub('Chrobot::', '').gsub('Action', '').gsub(/([A-Z])/, ' \1').strip
    end
    
    def serialize
      "#{serialized_class_name}#{serialize_spec_half}"
    end
    
    def serialized_class_name
      self.class.name.underscore
    end
    
    def self.load_from_serialized(serialized, item)
      if serialized =~ /\A([^|]+)(\|(.+))?\Z/u
        action_class = case $1
        when 'ds'
          DeferredAction
        when 'df'
          FastDeferredAction
        else
          $1.camelize.constantize
        end
                       
        action = action_class.new(*eval("[#{$3}]"))
        action.chrobot_item!(item)
        action.freeze
      else
        raise "couldn't deserialize"
      end
    end
    
    def chrobot_item!(item)
      @item = item
    end
    
    def self.queue!(*args)
      ChrobotItem.create!(:action => new(*args), :priority => action_priority)
    end

    # if you want to allocate a particular task to a specific chrobot
    # Be careful that you don't allocate a slow action to a chrobot that is only doing
    # fast actions... Used for cache clearing if there are multiple slices not sharing
    # release code... So don't use it...
    def self.allocate_and_queue!(bot, *args)
      ChrobotItem.create!(:action => new(*args), :priority => action_priority,
        :status => ChrobotItem::ALLOCATED, :allocated_on => Time.now.utc, :allocated_to => bot)
    end
    
    def self.schedule!(run_at, *args)
      ChrobotItem.create!(:action => new(*args), :priority => action_priority, :run_at => run_at)
    end

    def self.action_priority
      ChrobotItem::NORMAL_PRIORITY
    end
    
    private

    def serialize_spec_half
      @spec.empty? ? '' : "|#{string_spec(@spec)}"
    end
    
    def self.ar(klass, id)
      klass.find(id)
    end
    
    def self.m
      MAGIC_MARKER
    end
    
    def string_spec(v)
      raise "weird serialization" unless simplify_value(v).inspect =~ /\A\[(.*)\]\Z/
      
      $1
    end
    
    def simplify_value(v)
      if  v.nil? || 
          v.is_a?(TrueClass) ||
          v.is_a?(FalseClass) ||
          v.is_a?(String) || 
          v.kind_of?(Integer) || 
          v.is_a?(Symbol) ||
          v == MAGIC_MARKER
        v
      elsif v.is_a?(Date) ||
          v.is_a?(DateTime) ||
          v.is_a?(Time)
        "#{v}"
      elsif v.is_a?(Class) || v.is_a?(Module)
        ClassMarker.new(v)
      elsif v.is_a?(Array)
        v.map { |x| simplify_value(x) }
      elsif v.is_a?(Hash)
        v.map_to_hash { |k, x| [simplify_value(k), simplify_value(x)] }
      elsif v.kind_of?(ActiveRecord::Base)
        ActiveRecordReference.new(v)
      else
        raise "don't know how to simplify #{v.inspect} - #{v.class_name}"
      end
    end
    
  end
  
end