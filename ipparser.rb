# Copyright 2011 Dirk Haage. All rights reserved.
# This code is released under the BSD license, for details see the README file
require 'rubygems'
require 'ipmatcher'
require 'geoparser'
require 'thread'

# parser for ip data
# data format is:
# ip [val]
# missing values are set to 1
# example:
# 10.0.17.1   123
# 10.0.23.11  456
# 12.13.14.15
class IPParser < GeoParser::Base
  
  attr_accessor :matcher
  
  def initialize(file, host, user, pass, db, threads = 8)
    @file = file
    @host = host
    @user = user
    @pass = pass
    @db = db
    @threads = threads
    @reading = true
  end

  def db_connect
  
  # try to connect to the db
    begin
      return Ipmatcher::MaxMindMatcher.new(@host,@user,@pass,@db)
    rescue Exception => e
      puts "db access failed, but not required. continueing."
    end
  end 
  def each
    # reader queue
    test = 1000 * @threads
    inq = SizedQueue.new(test)    
    mutex = Mutex.new
	  # outgoing queue
    outq = Queue.new
    # producer
    reader = Thread.new do
      raise FileMissingError, "File not set" unless @file
      begin
        f = File.open(@file, "r")
        puts "start reader loop now"
        f.each do |l|
          #puts l
          inq << l
        end
      rescue => err
        err
      ensure
        @reading = false
        f.close
      end
    end
    # worker
    threads = []
    @threads.times do |t|
      threads[t] = Thread.new do
        puts "Thread #{t} started."
        # db connect
        dbc = db_connect
        while @reading or !inq.empty? do
          outq << string_to_data(dbc, inq.pop) if !inq.empty?
        end
      end
    end
    while true
      if  outq.empty?
        n = true
        threads.each do |t|
          n = (t.status === false) and n
        end
        if n
            puts "threads dead"
          break # get a kitkat
        end
      end
      yield outq.pop
    end
  end

  def string_to_data(dbc, string)
    data = string.chomp.split(' ')
    if data.length >0
      loc = dbc.get_coordinates(data[0])
      if loc
        if data.length == 1
          return {:lat => loc[0].to_f, :lon => loc[1].to_f, :val => 1}
        else
          return {:lat => loc[0].to_f, :lon => loc[1].to_f, :val => data[1].to_f, :ip => data[0]}
        end
      end
    end
    return nil
  end
  
  def data_to_string(data)
    begin
      "#{data[:ip]} #{data[:val]}".chomp      
    rescue Exception => e
      "#{data[:ip]}".chomp      
    end
    
  end
end

# parser for reversed ip data
# data format is:
# val ip
# example:
# 1234 10.0.17.1
#  123 10.0.23.11
class ReverseIPParser < GeoParser::Base

  attr_accessor :matcher
  
  def initiliaze(file = nil, ipmatcher = nil)
    @matcher = ipmatcher if ipmatcher
  end
  
  def string_to_data(string)
    data = string.chomp.split(' ')
    loc = @matcher.get_coordinates(data[1])
    {:lat => loc[0].to_f, :lon => loc[1].to_f, :val => data[0], :ip => data[1]}
  end
  
  def data_to_string(data)
    "#{data[:val]} #{data[:ip]}".chomp
  end
  
end
