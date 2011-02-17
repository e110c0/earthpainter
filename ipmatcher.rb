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
              start int,
              stop int,
              location int
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
          # put into db
          @db.query("insert into blocks values (" + start + "," + stop + "," + loc + ")")
          c += 1
          if (c%1000) == 0
            puts "inserted " + c.to_s + " blocks."
          end
        }
      elsif
        puts "No blocks file provided, not updating!"
      end
      puts "Finished. inserted " + c.to_s + " blocks."
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
        ip = IPAddr.new(ip).to_i.to_s
      elsif ip.class == Fixnum
        ip = ip.to_s
      else
        puts "unknown IP type!"
        return nil
      end
      return @db.query("SELECT location from blocks where (start <= " + ip.to_s + ") AND (stop >= " + ip.to_s + ") LIMIT 1")
      
    end
    
    
  end
end

m = Ipmatcher::MaxMindMatcher.new()#{}"localhost","ipmatcher","1pmatcher","maxmind",
                                  #{}"data/GeoLite_20110101/GeoLiteCity-Blocks.csv",
                                  #{}"data/GeoLite_20110101/GeoLiteCity-Location.csv")
m.update()
before = Time.new
(20...30).each{ |a|
  (30...40).each { |b|
    ip = a.to_s + "." + b.to_s + ".34.56"
    location = m.get_coordinates(ip)
    begin
      puts ip + ": " + location.to_s
    rescue Exception => e
      puts ip + ": none"
    end
  }
}
after = Time.new
puts "100 request in %f seconds"  % (after-before)