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
  
  attr_accessor :matcher, :table
  
  def initiliaze(file = nil, table = nil, ipmatcher = nil)
    @matcher = ipmatcher if ipmatcher
    @table = table if table
  end
  
  # store the data from file in db table
  def store_in_db
    raise FileMissingError, "File not set" unless @file
    puts "Storing data in database..."
    before = Time.now
    begin
      # create the table, check if table exists!! if so, do something usefull
      @matcher.db.query("drop table if exists input_#{@table}")
      @matcher.db.query("create table input_#{@table} (
                  ip int(10) UNSIGNED NOT NULL,
                  net int(10) UNSIGNED NOT NULL,
                  count real
                  );")
      @matcher.db.query("ALTER TABLE input_#{@table} engine=memory;")
      # store the data
      f = File.open(@file, "r")
      sets = Array.[]
      c = 0
      f.each do |l|
        d = string_to_db(l)
        if d
          sets.push(d)
        end
        c += 1
        if (c%100000) == 0
          @matcher.db.query("insert into input_#{@table}(ip, net, count) values " + sets.join(",") +";")
          sets = Array.[]
          puts "inserted " + c.to_s + " data sets."
        end
      end
      @matcher.db.query("insert into input_#{@table}(ip, net, count) values " + sets.join(",") +";")
      puts "Finished. Inserted " + c.to_s + " data sets in #{Time.now - before} seconds."
    rescue Exception => e
      puts e
    ensure
      f.close
    end
  end
  
  # match ips to locations and count hits
  def match_ips
    puts "Matching IPs to locations."
    before = Time.now
    # create result table
    @matcher.db.query("drop table if exists result_#{@table}")
    @matcher.db.query("CREATE TABLE `result_#{@table}` (
                        `x` double NOT NULL DEFAULT '0',
                        `y` double NOT NULL DEFAULT '0',
                        `count` int(11) unsigned NOT NULL DEFAULT '0',
                        PRIMARY KEY (`x`,`y`)
                        ) ENGINE=MEMORY;
                      ")
    # use fancy sql stuff to match all ips to locations
    @matcher.db.query("INSERT INTO result_#{@table}
                       SELECT locations.lat, locations.lon, input.count
                       FROM
                          input_#{@table} AS input,
                          blocks_mem AS blocks,
                          locations_mem AS locations
                       WHERE  input.net = blocks.index_geo
                       AND input.ip >= blocks.start
                       AND input.ip <= blocks.stop
                       AND blocks.location = locations.location
                       ON DUPLICATE KEY UPDATE result_#{@table}.count = result_#{@table}.count + input.count;")
    puts "Finished. Match all IPs in #{Time.now - before} seconds."
  end
  
  # transform input string to db data string
  def string_to_db(string)
    data = string.chomp.split(' ')
    if data.length >0
      begin
        ip = IPAddr.new(data[0]).to_i
        net = ip / 65536 * 65536
      rescue Exception => e
        return nil
      end
      if data.length == 1
        return "(#{ip},#{net},1)"
      else
        return "(#{ip},#{net},#{data[1]})"
      end
    end
  end
  
  def db_to_data(a)
    return {:lat => a[0].to_f, :lon => a[1].to_f, :val => a[2].to_i}
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
    # prepare data
    store_in_db
    match_ips
    # get full match table and yield each row
    rows = @matcher.db.query("SELECT * from result_#{@table}")
    rows.each do |l|
      yield db_to_data l
    end
  end
  
end