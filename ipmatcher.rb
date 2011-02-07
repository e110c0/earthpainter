require 'rubygems'
require 'redis'

rhost = "localhost"
rport = "6379"

def get_prefix_start(start,stop)
  return start & stop
end

def get_prefix_length(start,stop)
    (Math.log(stop-start+1)/Math.log(2)).ceil 
end

def get_prefix(start, stop)
  s = get_prefix_start(start, stop)
  l = get_prefix_length(start, stop)
  return s, l
end

# Initialize the connection to Redis
begin 
  r = Redis.new(:host => rhost, :port => rport)
rescue 
  abort("Redis could not connect")
end

File.open("data/GeoLite_20110101/GeoLiteCity-Blocks.csv").each{ |line|
  data = line.chomp.split(',')
  data.each{ |i|
    i.gsub!(/"/,'')
  }
  start = data[0].to_i
  stop = data[1].to_i
  loc = data[2]
  s,l = get_prefix(start, stop)
  puts s.to_s(2)[0..-l]
}