# Copyright 2011 Dirk Haage. All rights reserved.
# This code is released under the BSD license, for details see the README file

require 'rubygems'
require 'mysql'
require 'ipaddr'
require 'net/http'

module Ipmatcher
  class MaxMindMatcher
    
    def initialize(host = "localhost", user = nil , pass = nil , db = "maxmind")
      @db = Mysql.real_connect(host, user, pass, db)
      @blockselect = @db.prepare("SELECT lat,lon from blocks_copy as b,locations_copy as l 
                      WHERE index_geo = ? AND ? >= start AND ? <= stop 
                      AND b.location = l.location LIMIT 1;")
    end
    
    # download updates and update db
    def get_updates()
      # check for timestamp
      last = get_updatetime
      puts "Last update was #{last}."
      date = (Time.now.strftime("%Y%m") + "01").to_i
      if date > last
        # download
        host = "geolite.maxmind.com"
        file = "/download/geoip/database/GeoLiteCity_CSV/GeoLiteCity_#{date}.zip"
        lfile = "/tmp/GeoLiteCity_#{date}.zip"
        if not File.exist?(lfile)
          puts "Trying to download #{host}#{file}..."
          con = Net::HTTP.start(host)
          resp = con.get(file)
          open(lfile,"wb"){ |file|
            file.write(resp.body)
          }
          puts "done."
        else
          puts "File already there, skipping download."          
        end
        # unpack
        begin
          puts "Unpacking..."
          system("/usr/bin/unzip #{lfile} -d /tmp")
          puts "done."
        rescue Exception => e
          puts "Unpacking failed, sorry."
        end
        blocks = "/tmp/GeoLiteCity_#{date}/GeoLiteCity-Blocks.csv"
        locations = "/tmp/GeoLiteCity_#{date}/GeoLiteCity-Location.csv"

        # correct files for parsing
        # call update
        update(blocks, locations)

        set_updatetime(date)
        # delete /tmp/GeoLite dir
        File.delete(blocks)
        File.delete(locations)
        Dir.delete("/tmp/GeoLiteCity_#{date}")
      else
        puts "Database up to date!"
      end
    end
    
    def get_updatetime
      begin
        @db.query("SELECT data from meta where info='updatetime';").fetch_row[0].to_i
      rescue Exception => e
        return 0
      end
    end
    
    def set_updatetime(date)
      puts date
      begin
        @db.query("UPDATE meta SET data=#{date} WHERE info='updatetime';")
      rescue Exception => e
        puts e
        @db.query("create table meta (info varchar(255), data int(10) UNSIGNED NOT NULL);")
        @db.query("INSERT into meta (info,data) values ('updatetime', #{date});")
      end
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
          if data.length == 3
            begin
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
            rescue Exception => e
            end
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
        File.open(locations, "r:iso-8859-1").each{ |line|
          # read maxmind file
          data = line.chomp.split(',')
          data.each{ |i|
            i.gsub!(/"/,'')
          }
          if data.length >=7
            begin
              location = data[0]
              lat = data[5]
              lon = data[6]
              @db.query("insert into locations values (" + location + "," + lat + "," + lon + ")")
              c += 1
              if (c%10000) == 0
                puts "inserted " + c.to_s + " locations."
              end              
            rescue Exception => e
            end
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
      res = @blockselect.execute(index,ip,ip)
      begin
        #return res.fetch
        return [1,2]
      rescue Exception => e
        return nil
      end
    end
    
    ### convenient functions to prepare the database for painting
    # get a specific location by its id or a range if max is given
    # must be done, because ruby-mysql breaks for more than 100k rows in a result
    def get_location(id, max = nil)
      if max != nil then
        @db.query("SELECT lat,lon FROM locations WHERE location BETWEEN #{id} and #{max}")
      else
        @db.query("SELECT lat,lon FROM locations WHERE location = #{id};")
      end
    end
    
    # get ip count for a specific location of for all if id == nil
    def get_ips_per_location(id = nil)
      if id == nil then
        @db.query("SELECT blocks.location,locations.lat,locations.lon,SUM(DISTINCT(stop)-start+1)
                   FROM locations,blocks WHERE blocks.location = locations.location
                   GROUP BY blocks.location;")
      else
        @db.query("SELECT locations.lat,locations.lon,SUM(DISTINCT(stop)-start+1) 
                   FROM locations,blocks WHERE blocks.location=#{id} 
                   AND blocks.location = locations.location;")
      end
    end
    
    
    
  end ### End class
end ### End package








