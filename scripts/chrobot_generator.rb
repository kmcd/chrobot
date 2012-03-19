#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/../../../../config/environment.rb"

while true
  puts "creating #{Time.now.to_i}"
  ChrobotItem.create!(:action => Chrobot::DummyAction.new([true, false].rand, "1234567890" * rand(100)), :run_at => Time.now.utc + [0, 1, 2, 10, 20].rand)
  sleep [0.01, 0.02, 0.03, 2].rand
end
  