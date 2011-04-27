# Copyright 2011 Dirk Haage. All rights reserved.
# This code is released under the BSD license, for details see the README file

require "rubygems"
# Usage and options
require "getoptlong"
require "ipaddr"
require "ipmatcher"

# Usage output
def usage
  puts <<-EOS
  
net2locations: get a list of locations and IP count for each network 
               of a given network size. Resulting files can be easily
               painted with earthimgr.
 
Usage:

-h, --help:
    show help

-o, --output:
    Directory for the result files. Each network will be in a seperate file (default: .)
    
-n, --net:
    Prefix length for the networks (default. 16)

--host:
    host with the maxmind database (default: localhost)

--port:
    portnumber of the mysql server (default: 3306)

--dbname:
    database name (default: maxmind)

--user:
    username for the database (default: ipmatcher)

--pass:
    passwort fot the database

EOS
exit 
end

def get_networks(db,netsize)
  puts "getting /#{netsize} networks."
  if netsize == 16
    nets = db.query("
      select index_geo
      from blocks_mem 
      group by index_geo
      having count(index_geo) >= 1000
      ;
    ")
  elsif netsize < 16
    ipc = 2**(32-netsize)
    nets = db.query("
      select (index_geo - MOD(index_geo, #{ipc})) as slash8
      from blocks_mem group by slash8;
    ")
  else
    puts "not implemented yet, go fix the code!"
  end
  return nets
end

def get_locationcounts(db, net, netsize)
  if netsize == 16
    locs = db.query("
      select locations.lat, locations.lon, sum(blocks.stop - blocks.start +1)
      from blocks_mem as blocks, locations_mem as locations
      where index_geo = #{net}
      and locations.location = blocks.location
      group by blocks.location
      ;
    ")
  elsif netsize < 16
    ipc = 2**(32-netsize)
    # BUG: count is broken due to the db layout. networks < /16 are in the table multiple times
    # FIX: unique the rows before counting!
    locs = db.query("
      select locations.lat, locations.lon, sum(blocks.stop - blocks.start +1)
      from blocks_mem as blocks, locations_mem as locations
      where (index_geo - MOD(index_geo, #{ipc})) = #{net} 
      and locations.location = blocks.location
      group by blocks.location;
    ")
  else
    puts "not implemented yet, go fix the code!"
  end
  return locs
end
# --- main ---

# Specify options
opts = GetoptLong.new(
  [ "--help", "-h", GetoptLong::NO_ARGUMENT ],
  [ "--output", "-o", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--net", "-n", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--host", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--port", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--dbname", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--user", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--pass", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--updatedb", GetoptLong::OPTIONAL_ARGUMENT ]
  )
output = "."
dbhost = "localhost"
dbport = "3306"
db = "maxmind"
dbuser = "ipmatcher"
dbpass = ""
net = 16
# Parse options
opts.each do |opt, arg|
  case opt
  when "--help"
    usage
  when "--output"
    puts arg
    if File.directory?(arg)
      output = arg
    else
      puts "Output must be a directory!"
      exit
    end
  when "--net"
    net = arg.to_i
  when "--host"
    dbhost = arg
  when "--port"
    dbport = arg
  when "--db"
    db = arg
  when "--user"
    dbuser = arg
  when "--pass"
    dbpass = arg
  end
end


# try to connect to the db
begin
  $matcher = Ipmatcher::MaxMindMatcher.new(dbhost,dbuser,dbpass,db)
rescue Exception => e
  puts e
  puts "db access failed, but required. exiting."
  Process.exit
end

# bypassing the convenience functions and directly work with sql
con = $matcher.db

nets = get_networks(con,net)

nets.each do |n|
  # generate filename here and open file
  filename = IPAddr.new(n[0].to_i, Socket::AF_INET).to_s + "-#{net}"
  f = File.open(File.join(output,filename + '.csv'),'w+')
  puts "thats a network: #{filename}, saving it to #{File.join(output,filename)}.csv"
  loccounts = get_locationcounts(con, n[0], net)
  loccounts.each do |l|
    # append to file
    f.write "#{l[0]} #{l[1]} #{l[2]}\n"
  end
end