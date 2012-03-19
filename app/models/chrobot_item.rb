class ChrobotItem < ActiveRecord::Base

  SCHEDULED = 5 # NOT ACTUALLY USED
  PENDING = 10
  ALLOCATED = 20
  STARTED = 30
  FINISHED = 40
  FAILED = 100
  
  ALL_STATUSES = [SCHEDULED, PENDING, ALLOCATED, STARTED, FINISHED, FAILED]
  ALL_STATUS_COUNTS_ZERO = ALL_STATUSES.map_to_hash { |s| [s, 0] }.freeze

  # priority values
  LOW_PRIORITY = 50
  NORMAL_PRIORITY = 100
  USER_WAITING_PRIORITY = 150
  HIGH_PRIORITY = 200
  URGENT_PRIORITY = 250

  ALL_PRIORITIES = [LOW_PRIORITY, NORMAL_PRIORITY, USER_WAITING_PRIORITY, HIGH_PRIORITY, URGENT_PRIORITY]
  
  # created_on
  
  # lock_version
  
  # run_at
  validates_presence_of :run_at
  default_value_for(:run_at, nil) { Time.now.utc }
  
  named_scope :startable, proc { |time| { :conditions => ['run_at <= ?', time] } }
  
  # allocated_on
  validates_nil :allocated_on, :if => :pending?
  validates_presence_of :allocated_on, :if => :ever_allocated?
  
  # started_on
  validates_presence_of :started_on, :if => :ever_started?
  
  # completed_on
  validates_presence_of :completed_on, :if => :completed?
  
  # allocated_to
  validates_nil :allocated_to, :if => :pending?
  validates_presence_of :allocated_to, :if => :ever_allocated?
  validates_length_of :allocated_to, :maximum => 32, :allow_nil => true
  
  named_scope :allocated_to, proc { |name| { :conditions => { :allocated_to => name } } }

  # status_message
  validates_nil_or_not_blank :status_message
  ensures_nil_or_not_blank :status_message
  validates_length_of :status_message, :maximum => 255, :allow_nil => true
  
  # slow?
  boolean_field :slow, :default => false, :true_scope => :slow, :false_scope => :fast

  # status
  validates_integer :status, :tiny_unsigned
  validates_inclusion_of :status, :in => [PENDING, ALLOCATED, STARTED, FINISHED, FAILED]
  default_value_for :status, PENDING
  
  # priorty
  named_scope :scheduled, proc { {:conditions => ['status = ? and run_at > ?', PENDING, Time.zone.now ], :order => 'priority DESC, run_at'}}
  named_scope :pending, proc { {:conditions => ['status = ? and run_at < ?', PENDING, Time.zone.now ], :order => 'priority DESC, run_at' }}
  named_scope :allocated, :conditions => { :status => ALLOCATED }, :order => 'priority DESC, run_at'
  named_scope :started, :conditions => { :status => STARTED }, :order => 'priority DESC, run_at'
  named_scope :finished, :conditions => { :status => FINISHED }, :order => 'priority DESC, run_at'
  named_scope :failed, :conditions => { :status => FAILED }, :order => 'priority DESC, run_at'

  # priority
  validates_integer :priority, :tiny_unsigned
  validates_inclusion_of :priority, :in => ALL_PRIORITIES
  default_value_for :priority, NORMAL_PRIORITY
  
  # repetition_spec
  #validates_nil_or_not_blank :repetition_spec
  #ensures_nil_or_not_blank :repetition_spec
  
  # action_serialized
  validates_presence_of :action_serialized
  validates_length_of :short_action_serialized, :maximum => 255, :allow_nil => true
  validates_nil_or_not_blank :long_action_serialized
  
  def action_serialized
    long_action_serialized.nil? ? short_action_serialized : "#{short_action_serialized}#{long_action_serialized}"
  end
  
  def action_serialized=(new_action_serialized)
    if new_action_serialized.nil?
      self.short_action_serialized = nil     # won't validate, but that's what they're asking us for...
      self.long_action_serialized = nil      
    elsif new_action_serialized.length <= 255
      self.short_action_serialized = new_action_serialized
      self.long_action_serialized = nil
    else
      self.short_action_serialized = new_action_serialized[0,255]
      self.long_action_serialized = new_action_serialized[255 .. -1]
    end
  end
  
  # retry_count
  validates_integer :retry_count, :standard
  default_value_for :retry_count, 0
  
  # reschedule_count
  validates_integer :reschedule_count, :standard
  default_value_for :reschedule_count, 0
  
  # failure_message
  validates_nil_or_not_blank :failure_message
  ensures_nil_or_not_blank :failure_message
  
  #################################################################################################

  def action
    @action ||= Chrobot::Action.load_from_serialized(action_serialized, self)
  end

  def action=(a)
    @action = a.freeze
    self.action_serialized = a.serialize
    self.slow = a.slow?
  end
  
  def status_text
    case status
    when PENDING
      retry_count > 0 ? "pending retry" : "pending"
    when ALLOCATED
      "allocated"
    when STARTED
      "started"
    when FINISHED
      "finished"
    when FAILED
      "failed"
    else
      status.to_s
    end
  end

  def priority_text
    return "n/a" unless priority
    case priority
    when LOW_PRIORITY
      'Low'
    when NORMAL_PRIORITY
      'Normal'
    when USER_WAITING_PRIORITY
      'User Waiting'
    when HIGH_PRIORITY
      'High'
    when URGENT_PRIORITY
      'Urgent'
    else
      priority.to_s
    end
  end
  
  def action_name
    if email?
      if short_action_serialized =~ /\Achrobot\/smtp_action\|.*, nil,/
        "email (no recipients)"
      else
        "email"
      end
    elsif short_action_serialized =~ /\Ad[sf]\|ar\(([^,]+), (\d+)\), :([^,]+)/
      "#{$1}(#{$2}).#{$3}"
    elsif short_action_serialized =~ /\Ads?\|([^,]+), :([^,]+)/
      "#{$1}.#{$2}"
    elsif short_action_serialized =~ /\A([\w\/]+)/
      $1.classify
    elsif short_action_serialized =~ /\A([^\|]+)/
      $1
    else
      short_action_serialized
    end
  end
  
  def action_parameters
    if action_serialized =~ /\A[^\|]+\|(.*)\Z/
      $1
    else
      nil
    end
  end
  
  # this bit is lame
  def email?
    short_action_serialized =~ /\Achrobot\/smtp_action\|/
  end
  
  def email_sender
    return nil unless email?
    
    eval("[#{action_parameters}]")[0]
  end
  
  def email_recipients
    return nil unless email?
    
    eval("[#{action_parameters}]")[1]
  end
  
  def email_text
    return nil unless email?
    
    # this should be okay, it'll all be strings and arrays
    eval("[#{action_parameters}]")[2]
  end

  #################################################################################################
  
  def scheduled?
    status == PENDING && run_at >  Time.zone.now
  end

  def pending?
    status == PENDING && run_at < Time.zone.now
  end
  
  def allocated?
    status == ALLOCATED
  end

  def ever_allocated?
    status >= ALLOCATED
  end
  
  def started?
    status == STARTED
  end
  
  def ever_started?
    status >= STARTED
  end
  
  def finished?
    status == FINISHED
  end
  
  def failed?
    status == FAILED
  end
  
  def completed?
    finished? || failed?
  end
  
  def self.counts_per_status # Bit shit, but not spilts out the scheduled and pending as they both have the same status, just different run_at
    a = ALL_STATUS_COUNTS_ZERO.merge(count(:all, :group => 'status').to_hash)
    a[SCHEDULED] = scheduled.size
    a[PENDING] = a[PENDING] - scheduled.size
    a
  end
  
  #################################################################################################

  def allocate_to!(worker_name)
    raise "can't be allocated" unless pending?
    
    update_attributes!(:status => ALLOCATED, :allocated_on => Time.now.utc, :allocated_to => worker_name)
  end

  # you might call this from the console
  def manual_process!
    allocate_to!('MANUAL')
    process!
  end

  def process!(timeout_seconds = nil)
    raise "not processable" unless allocated?
    
    # we do the start and finish outside the block, so we don't cause a failure if the start/finish fail...
    start!
    
    begin
      action.internal_process(timeout_seconds)
    rescue Chrobot::InterruptException
      fail!(exception_message, action.retry_after_interrupt?)
    rescue Chrobot::TimeoutException
      fail!(exception_message, action.retry_after_timeout?)
    rescue Exception
      fail!(exception_message, action.retry_after_exception?)
    end
    
    finish! if started?
  end

  def failure_message_short
    return nil if failure_message.blank?

    failure_message.to_a[0].strip
  end

  def add_message!(message)
    update_attributes(:status_message => [status_message, message].join(' '))
  end

  private
  
  def exception_message(exception = $!, backtrace = $@)
    "#{exception.class}: #{exception}\n#{backtrace.join("\n")}"
  end
  
  public

  #################################################################################################
  
  def start!(now = Time.now.utc)
    raise "already started" if ever_started?
    
    update_attributes(:status => STARTED, :started_on => now)
  end
  
  def finish!(now = Time.now.utc)
    complete!(FINISHED, nil, now)
  end
  
  def fail!(message, try_again = false, now = Time.now.utc)
    transaction do
      complete!(FAILED, message, now)
      retry!(now) if try_again
    end
  end
  
  private
  
  def complete!(status, message, now)
    raise "already complete" if completed?
    raise "not started" unless started?
    
    update_attributes(:status => status, :failure_message => message, :completed_on => now)    
  end
  
  public
  
  # back off the retries
  # (0..20).inject(10) { |t, x| puts ((t + x * 10) / 60.0); t + x * 10 }
  def retry_interval
    if retry_count < 20
      10 + retry_count * 10
    else
      30 * 60   # half hour retries?
    end
  end
  
  def retry!(now = Time.now.utc)
    raise "not failed!" unless failed?
    
    update_attributes!(:status => PENDING, :run_at => now + retry_interval, :allocated_to => nil, :allocated_on => nil, :retry_count => retry_count + 1)
  end
    
  #################################################################################################

  # call this as you're starting up to fail all the actions you started but died doing last time...
  def self.fail_all_for(worker_name, now = Time.now.utc)
    transaction do
      started.allocated_to(@name).each { |i| i.fail!('mysterious failure; check the Chrobot log', false, now) }
    end
  end

  def self.grab(worker_name, allow_slow = true, fast_count = 1, now = Time.now.utc)
    return [] if allow_slow && pending.startable(now).count == 0    # horrible only needed to make slow less inefficient
    
    # basically, to stop us getting a mix of fast/slow and then making the fast take ages to complete,
    # we only get one slow one -- if we don't get any slow ones, we get GRAB_SIZE fast ones.  If we don't
    # find anything, we sleep.
    # 
    # Chrobots that don't allow slow items will just get the fast ones.

    if allow_slow
      result = grab_fast_or_slow(worker_name, true, 1, now)
      
      result.empty? ? grab_fast_or_slow(worker_name, false, fast_count, now) : result
    else
      grab_fast_or_slow(worker_name, false, fast_count, now)
    end
  end

  # grab an item from the unallocated queue -- this all happens in a transaction, should be thread-safe; returns all items allocated to name
  def self.grab_fast_or_slow(worker_name, slow, count, now = Time.now.utc)
    items = slow ? pending.startable(now).slow : pending.startable(now).fast
    
    if 0 < items.count &&
       0 < items.update_all(['lock_version = lock_version + 1, status = ?, allocated_to = ?, allocated_on = ?', ALLOCATED, worker_name, now], nil, :limit => count, :order => 'priority DESC, run_at')
      allocated.allocated_to(worker_name)
    else
      []
    end
  end
  
end