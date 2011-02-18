require 'rubygems'
require 'mysql'
require 'ipaddr'

module Ipmatcher
  class MaxMindMatcher
    
    def initialize(host = "localhost", user = "ipmatcher", pass = "1pmatcher", db = "maxmind", blocks = nil, locations = nil)
      @blocks = blocks
      @locations = locations
      @db = Mysql.real_connect(host, user, pass, db)
    end
    
    def update()
      c = 0
      if @blocks != nil
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
        File.open(@blocks).each{ |line|
          # read maxmind file
          data = line.chomp.split(',')
          data.each{ |i|
            i.gsub!(/"/,'')
          }
          start = data[0]
          stop = data[1]
          loc = data[2]
          index = (stop.to_i / 65536 * 65536).to_s
          # put into db
          @db.query("insert into blocks (start, stop, location, index_geo) values (" +
                     start +  "," + stop + "," + loc + "," + index + ")")
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
      if @locations != nil
        # delete & prepare table
         @db.query("drop table if exists locations")
        rows = @db.query(
            "create table locations (
              location int,
              lat real,
              lon real
            );"
          )
        File.open(@locations).each{ |line|
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
          if (c%1000) == 0
            puts "inserted " + c.to_s + " locations."
          end
        }
      elsif
        puts "No location file provided, not updating"
      end
      puts "Finished. inserted " + c.to_s + " locations."
    end

    def get_coordinates(ip)
      if ip.class == String
        ip = IPAddr.new(ip).to_i
      elsif ip.class == Fixnum
        # do nothing
      else
        puts "unknown IP type!"
        return nil
      end
      index = ip - (ip%65536)
      res = @db.query("SELECT location from blocks where index_geo = " + index.to_s + 
                      " AND " + ip.to_s + " BETWEEN start AND stop LIMIT 1")
      if res.nil? then
        return nil
      else
        r = res.fetch_row
        return r
      end
    end
    
    
  end
end

m = Ipmatcher::MaxMindMatcher.new("localhost","ipmatcher","1pmatcher","maxmind")
                                  #{}"data/GeoLite_20110101/GeoLiteCity-Blocks.csv")
                                  #{}"data/GeoLite_20110101/GeoLiteCity-Location.csv")
m.update()
before = Time.new
(0...256).each{ |a|
  (0...256).each { |b|
    ip = a.to_s + "." + b.to_s + ".34.56"
    location = m.get_coordinates(ip)
    if not location.nil? then
      puts ip + ": " + location.to_s
    end
  }
}
after = Time.new
puts "10000 request in %f seconds"  % (after-before)