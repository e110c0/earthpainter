require 'rubygems'
require 'sqlite3'



module Ipmatcher
  class MaxMindMatcher
    include SQLite3
    
    def initialize(db, blocks = nil, locations = nil)
      @blocks = blocks
      @locations = locations
      @db = Database.new(db)
    end
    
    def update()
      c = 0
      begin
        File.open(@blocks).each{ |line|
          # delete & prepare table
          @db.execute("drop table if exists blocks")
          rows = @db.execute <<-SQL
              create table blocks (
                start int,
                stop int,
                location int
              );
            SQL
          # read maxmind file
          data = line.chomp.split(',')
          data.each{ |i|
            i.gsub!(/"/,'')
          }
          start = data[0].to_i
          stop = data[1].to_i
          loc = data[2].to_i
          # put into db
          @db.execute("insert into blocks values (?,?,?)", start, stop, loc)
          c += 1
          if (c%1000) == 0
            puts "inserted " + c.to_s + " blocks."
          end
        }
      rescue Exception => e
        puts e
        puts "No blocks file provided, not updating!"
      end
      puts "Finished. inserted " + c.to_s + " blocks."
      c = 0
      begin
        File.open(@locations).each{ |line|
          # delete & prepare table
           @db.execute("drop table if exists locations")
          rows = @db.execute <<-SQL
              create table locations (
                location int,
                lat real,
                lon real
              );
            SQL
          # read maxmind file
          data = line.chomp.split(',')
          data.each{ |i|
            i.gsub!(/"/,'')
          }
          location = data[0].to_i
          lat = data[5].to_f
          lon = data[6].to_f
          @db.execute("insert into locations values (?,?,?)", location, lat, lon)
          c += 1
          if (c%1000) == 0
            puts "inserted " + c.to_s + " locations."
          end
        }
      rescue Exception => e
        puts e
        puts "No location file provided, not updating"
      end
      puts "Finished. inserted " + c.to_s + " locations."
    end
  end
end

m = Ipmatcher::MaxMindMatcher.new("maxmind.db")#,
                                  #"data/GeoLite_20110101/GeoLiteCity-Blocks.csv",
                                  #"data/GeoLite_20110101/GeoLiteCity-Location.csv")
m.update()

