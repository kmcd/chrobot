module Chrobot
  
  class Worker
    
    SHORT_SLEEP_TIME = 5
    LONG_SLEEP_TIME = 15
    HYPERACTIVE = 10    # hyperactive for 10 seconds
    BOREDOM = 400       # around half an hour
    
    FAST_MAX_PROCESSING_TIME = 60*2
    SLOW_MAX_PROCESSING_TIME = 60*45
    PROCESSING_TIME_MARGIN = 30
    GRAB_SIZE = 5
    
    def initialize(name, allow_slow, keep_running = true)
      raise "name too long!" if name.length > 32
      
      @name = name
      @keep_running = keep_running
      @allow_slow = allow_slow
      @raise_interrupts = false
    end
    
    def run_forever
      setup_signals
      log_startup
      
      # fail ones we started before, but died
      protect_timeout { ChrobotItem.fail_all_for(@name) }

      # run ones we were allocated before
      process_all_allocated_to_me

      sleep_ticker = 0
      sleep_loops = 0
      
      while(@keep_running)
        items = protect_timeout([]) { ChrobotItem.grab(@name, @allow_slow, GRAB_SIZE) }

        if items.empty?
          if sleep_loops < HYPERACTIVE
            light_sleep(1)
          elsif sleep_loops < BOREDOM
            light_sleep(SHORT_SLEEP_TIME + rand(6) - 3)
          else
            light_sleep(LONG_SLEEP_TIME + rand(10) - 5)
          end
          
          sleep_loops += 1

          # just in case, see what's allocated to us -- seems unlikely that it'll be anything...
          process_all_allocated_to_me if sleep_loops % 5 == 0
        else
          process_all(items)
          sleep_loops = 0
        end      
      end
      
      log_shutdown
      
    rescue Exception
      log_exception(__FILE__, __LINE__)
      log_shutdown('died')
    ensure
      shutdown_signals
    end

    private

    def setup_signals
      @old_int_signal = Signal.trap('INT') { interrupt("CTRL+C detected.") }    # CTRL+C
      @old_term_signal = Signal.trap('TERM') { interrupt("SIGTERM detected.") }   # standard kill
    end
    
    def interrupt(message)
      puts message
      @keep_running = false
      raise InterruptException.new(message) if @raise_interrupts
    end
        
    def shutdown_signals
      Signal.trap('INT', @old_int_signal)
      Signal.trap('TERM', @old_term_signal)
    end
    
    def log_startup
      puts "Chrobot '#{@name}' started #{Time.zone.now}."
      logger.info "---------------------------------------------------------------------------------------\nChrobot '#{@name}' started at #{Time.now.utc}"      
    end
    
    def log_shutdown(message = 'stopped')
      logger.info "---------------------------------------------------------------------------------------\nChrobot '#{@name}' #{message} at #{Time.now.utc}"
      puts "Chrobot #{message}."      
    end

    def timeout_value_for_item(item)
      item && item.slow? ? SLOW_MAX_PROCESSING_TIME : FAST_MAX_PROCESSING_TIME
    end

    # run a block with a fair amount of exception catching, and logging of those exceptions
    # also runs with a timeout to kill things that run for too long
    def protect(default = nil, item_being_processed = nil)
      begin
        # reactivate the connection if needed
        ActiveRecord::Base.connection.reconnect! unless ActiveRecord::Base.connection.active?
        
        yield
      rescue Exception
        log_exception(__FILE__, __LINE__, item_being_processed)
        default
      end
    rescue Exception  # double exception? (database is dead or something?)
      log_exception(__FILE__, __LINE__)
      default
    end

    def protect_timeout(default = nil, item_being_processed = nil)
      protect(default, item_being_processed) do
        timeout_value = item_being_processed ? timeout_value_for_item(item_being_processed) : FAST_MAX_PROCESSING_TIME
        
        timeout(timeout_value + PROCESSING_TIME_MARGIN, TimeoutException) do
          yield
        end        
      end
    end

    # sleeps, waiting for interrupts
    def light_sleep(seconds)
      @raise_interrupts = true
      sleep seconds
    rescue InterruptException
      # nothing, just return
    ensure
      @raise_interrupts = false
    end

    def process_all_allocated_to_me
      process_all(ChrobotItem.allocated.allocated_to(@name))
    end

    def process_all(items)
      return if items.empty?
      
      protect do
        items.sort_by { |item| item.run_at }.each do |item|
          return unless @keep_running
          
          protect_timeout(nil, item) { process_item(item) }
        end
      end
    end

    def process_item(item)
      @raise_interrupts = item.action.interruptable?
      item.process!(timeout_value_for_item(item))  
    ensure
      @raise_interrupts = false
    end


    def log_exception(file, line, item = nil)
      logger.error("*************************************************************\nRESCUED AT #{file}:#{line}\n#{exception_message(item, $!, $@)}\n*************************************************************")
      nil
    end
        
    def exception_message(item, e, backtrace)
      backtrace = [backtrace] unless backtrace.is_a?(Array)
      
      if item
        "Chrobot '#{@name}' at #{Time.now.utc}:\n#{e.class} while processing item #{item.id}: #{e}\n#{backtrace.join("\n")}"
      else
        "Chrobot '#{@name}' at #{Time.now.utc}:\n#{e.class}: #{e}\n#{backtrace.join("\n")}"
      end
    end
    
    def logger
      RAILS_DEFAULT_LOGGER
    end
    
  end
  
end