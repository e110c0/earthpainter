# Copyright 2011 Dirk Haage. All rights reserved.
# This code is released under the BSD license, for details see the README file

require 'rubygems'
require 'mysql'
require 'ipaddr'
require 'net/http'

module Ipmatcher
  class MaxMindMatcher
    
    attr_accessor :db
    
    def initialize(host = "localhost", user = nil , pass = nil , db = "maxmind")
      @db = Mysql.real_connect(host, user, pass, db)
      # if the memupdate fails, the db seems to be in an inconsistent state
      # forcing update!
      begin
        db2mem        
      rescue Exception => e
        puts "Database seems to be in an inconsistent state, forcing update!"
        get_updates()
        db2mem
      end
      @blockselect = @db.prepare("SELECT lat,lon from blocks_mem as b,locations_mem as l 
                      WHERE index_geo = ? AND ? >= start AND ? <= stop 
                      AND b.location = l.location LIMIT 1;")
    end
    
    # download updates and update db
    def get_updates()
      # check for timestamp
      last = get_metainfo("updatetime")
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

        set_metainfo("updatetime", date)
        # delete /tmp/GeoLite dir
        File.delete(blocks)
        File.delete(locations)
        Dir.delete("/tmp/GeoLiteCity_#{date}")
        # update in-memory tables
        db2mem
      else
        puts "Database up to date!"
      end
    end

    def get_metainfo(key)
      begin
        @db.query("SELECT data from meta where info='#{key}';").fetch_row[0].to_i
      rescue Exception => e
        return 0
      end
    end
    
    def set_metainfo(key, value)
      begin
        puts "setting meta info #{key}:#{value}"
        @db.query("UPDATE meta SET data=#{value} WHERE info='#{key}';")
      rescue Exception => e
        puts e
        puts "inserting meta info #{key}:#{value}"
        @db.query("INSERT into meta(info,data) values ('#{key}', #{value});")
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
              PRIMARY KEY (`id`)
            );"
          )
        sets = Array.[]
        File.open(blocks).each{ |line|
          # read maxmind file
          data = line.chomp.split(',')
          data.each{ |i|
            i.gsub!(/"/,'')
          }
          if data.length == 3 and data[0] != "startIpNum"
            begin
              start = data[0]
              stop = data[1]
              loc = data[2]
              index_start = (start.to_i / 65536 * 65536)
              index_stop = (stop.to_i / 65536 * 65536)
              # put into string
              (0..( (index_stop-index_start)/65536 )).each{ |i|
                index = (index_start + i * 65536).to_s
                sets.push("(#{start}, #{stop}, #{loc}, #{index})")
              }
              c += 1
              # put into db
              if (c%20000) == 0
                @db.query("insert into blocks (start, stop, location, index_geo) values " + sets.join(",") +";")
                sets = Array.[]
                puts "inserted " + c.to_s + " blocks."
              end
            rescue Exception => e
              puts "error in filling blocks: #{e}"
            end
          end
        }
        @db.query("insert into blocks (start, stop, location, index_geo) values " + sets.join(",") +";")
        puts "Finished. inserted " + c.to_s + " blocks."
        @db.query("CREATE INDEX idx_geo on blocks(index_geo);")
        puts "Created indexes."
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
              PRIMARY KEY (location)
            );"
          )
        sets = Array.[]
        File.open(locations, "r:iso-8859-1").each{ |line|
          # read maxmind file
          data = line.chomp.split(',')
          data.each{ |i|
            i.gsub!(/"/,'')
          }
          if data.length >=7 and data[0] != "locId"
            begin
              location = data[0]
              lat = data[5]
              lon = data[6]
              sets.push("(#{location}, #{lat}, #{lon})")
              c += 1
              if (c%10000) == 0
                @db.query("insert into locations(location, lat, lon) values " + sets.join(",") +";")
                sets = Array.[]
                puts "inserted " + c.to_s + " locations."
              end
            rescue Exception => e
              puts e
            end
          end
        }
        @db.query("insert into locations(location, lat, lon) values " + sets.join(",") +";")
        puts "Finished. inserted " + c.to_s + " locations."
        @db.query("CREATE INDEX idx_loc on locations(location);")
        puts "Created indexes."
      elsif
        puts "No location file provided, not updating"
      end
    end

    # create in memory copies of the db
    def db2mem
      # check for in memory tables
      # if not exist -> create
      # if exist and outdated -> drop and create
      tdate = get_metainfo("updatetime")
      mdate = get_metainfo("memtime")
      if mdate == tdate
        return
      end
      begin
        # drop & create tables
        @db.query("drop table if exists blocks_mem")
        @db.query("drop table if exists locations_mem")
        puts "In-memory tables outdated, dropping."
        @db.query("CREATE TABLE blocks_mem like blocks;")
        @db.query("ALTER TABLE blocks_mem engine=memory;")
        @db.query("INSERT into blocks_mem SELECT * FROM blocks;")
        @db.query("CREATE TABLE locations_mem like locations;")
        @db.query("ALTER TABLE locations_mem engine=memory;")
        @db.query("INSERT into locations_mem SELECT * FROM locations;")
        set_metainfo("memtime", tdate)
        puts "Updated in-memory tables."
      rescue Exception => e
        puts e
        raise e
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
    
    # get ip count for a specific location or for all if id == nil
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








