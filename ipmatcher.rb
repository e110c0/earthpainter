# Copyright 2011 Dirk Haage. All rights reserved.
# This code is released under the BSD license, for details see the README file

require 'rubygems'
require 'mysql'
require 'ipaddr'

module Ipmatcher
  class MaxMindMatcher
    
    def initialize(host = "localhost", user = nil , pass = nil , db = "maxmind")
      @db = Mysql.real_connect(host, user, pass, db)
    end
    
    def update(blocks = nil, locations = nil)
      c = 0
      if blocks != nil
        @db.query("drop table if exists blocks")
        rows = @db.query(
            "create table blocks (
              id int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
              start int(10) UNSIGNED NOT NULL,
              stop int(10) UNSIGNED NOT NULL,
              location int(10) UNSIGNED NOT NULL,
              index_geo INT(10) UNSIGNED NOT NULL,
              PRIMARY KEY (`id`),
              INDEX idx_start (start),
              INDEX idx_stop (stop),
              INDEX idx_geo (index_geo)
            );"
          )
        File.open(blocks).each{ |line|
          # read maxmind file
          data = line.chomp.split(',')
          data.each{ |i|
            i.gsub!(/"/,'')
          }
          start = data[0]
          stop = data[1]
          loc = data[2]
          index_start = (start.to_i / 65536 * 65536)
          index_stop = (stop.to_i / 65536 * 65536)
          # put into db
          (0..( (index_stop-index_start)/65536 )).each{ |i|
            index = (index_start + i * 65536).to_s
            @db.query("insert into blocks (start, stop, location, index_geo) values (" +
                     start +  "," + stop + "," + loc + "," + index + ")")
          }
          c += 1
          if (c%10000) == 0
            puts "inserted " + c.to_s + " blocks."
          end
        }
        puts "Finished. inserted " + c.to_s + " blocks."
        #@db.query("update blocks set index_geo = (stop - mod(stop, 65536));")
      elsif
        puts "No blocks file provided, not updating!"
      end
      c = 0
      if locations != nil
        # delete & prepare table
         @db.query("drop table if exists locations")
        rows = @db.query(
            "create table locations (
              location int,
              lat real,
              lon real,
              PRIMARY KEY (location),
              INDEX idx_loc (location)
            );"
          )
        File.open(locations).each{ |line|
          # read maxmind file
          data = line.chomp.split(',')
          data.each{ |i|
            i.gsub!(/"/,'')
          }
          location = data[0]
          lat = data[5]
          lon = data[6]
          @db.query("insert into locations values (" + location + "," + lat + "," + lon + ")")
          c += 1
          if (c%10000) == 0
            puts "inserted " + c.to_s + " locations."
          end
        }
        puts "Finished. inserted " + c.to_s + " locations."
      elsif
        puts "No location file provided, not updating"
      end
    end

    # return the geo coordinates for an IP in an array [lat, lon] or nil if no location is known
    def get_coordinates(ip)
      if ip.class == String
        ip = IPAddr.new(ip).to_i
      elsif ip.class == Fixnum
        # do nothingich 
      else
        puts "unknown IP type!"
        return nil
      end
      # this is the maxmind idea of a speed up. not sure this works
      # some of the ip blocks are larger than 65k
      # the fix for this is in updating the database and duplicating the rows for each /16
      index = ip - (ip%65536)
      res = @db.query("SELECT location from blocks where index_geo = " + index.to_s + 
                      " AND " + ip.to_s + " BETWEEN start AND stop LIMIT 1")
      #res = @db.query("SELECT location from blocks where " + ip.to_s + " BETWEEN start AND stop LIMIT 1")
      begin
        r = res.fetch_row[0]
        l = @db.query("SELECT lat,lon from locations where location = #{r} LIMIT 1;").fetch_row
        return l     
      rescue Exception => e
        return nil
      end
    end
        
  end
end