# Copyright 2011 Dirk Haage. All rights reserved.
# This code is released under the BSD license, for details see the README file
require 'rubygems'
require 'ipmatcher'
require 'geoparser'

require 'time'

# parser for ip data
# data format is:
# ip [val]
# missing values are set to 1
# example:
# 10.0.17.1   123
# 10.0.23.11  456
# 12.13.14.15
# data is initially stored in a temporary table of the db to speed up processing

class InDBParser < GeoParser::Base
  
  attr_accessor :matcher
  
  def initiliaze(file = nil, table = nil ipmatcher = nil)
    @matcher = ipmatcher if ipmatcher
    if table
      @table = table
    else
      @table = Time.now.to_i.to_s
    end
    store_in_db
  end
  
  # store the data from file in db table
  def store_in_db
    raise FileMissingError, "File not set" unless @file
    begin
      #create the table, check if table exists!! if so, do something usefull
      
      # store the data
      f = File.open(@file, "r")
      sets = Array.[]
      c = 0
      f.each do |l|
        sets.push(string_to_string(l))
        if (c%100000) == 0
          @db.query("insert into #{@table}(ip, count) values " + sets.join(",") +";")
          sets = Array.[]
          puts "inserted " + c.to_s + " locations."
        end
      end
    rescue => err
      err
    ensure
      f.close
    end
  end
  
  # match ips to locations and count hits
  def match_ips
    # use fancy sql stuff to match all ips to locations
  end
  
  # transform input string to db data string
  def string_to_db(string)
    data = string.chomp.split(' ')
    if data.length >0
      begin
        ip = IPAddr.new(data[0]).to_i.to_s        
      rescue Exception => e
        puts "unknown IP type!"
        return nil
      end
      if data.length == 1
        return "(#{ip},1)"
      else
        return "(#{ip},#{data[1]})"
      end
    end
  end
  
  def string_to_data(string)
    data = string.chomp.split(' ')
    if data.length >0
      loc = @matcher.get_coordinates(data[0])
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
  
  # new each that returns the result from the db
  def each
    # get full match table and yield each row
  end
  
end