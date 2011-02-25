# Copyright 2011 Dirk Haage. All rights reserved.
# This code is released under the BSD license, for details see the README file

require "rubygems"
# Usage and options
require "getoptlong"

require "geoparser"
require "ipmatcher"
require "earthpainter"
require "ipparser"

# Usage output
def usage
  puts <<-EOS
  
earthimgr: create geographical representations of IP-based data 
 
Usage:

-h, --help:
    show help

-o, --output:
    Name of the resulting image
    
-i, --input:
    Input textfile

-I, --input-type:
    Specify the data representation of the input file:
      maxmind: maxmind location file
      hip: hostip city file
      ip: space separated "IP(v4) [val]", missing values are set to 1
      reverseip: space separated "val IP(v4)"
      generic: space separated "lat lon val" (default)
    
-H, --height:
    Height of resulting image. Width is always size*2 (default: 900)

-c, --colormap:
    Specify colormap present as YAML file (currently not implemented)

-m, --maxvalue:
    Specify the maximum value (float or int) within the dataset to scale the 
    colorgradient. If the given number is smaller than the actual, all higher
    values will map to the highest color. Useful to achieve same colors for 
    different data sets. (default: maximum found in data)

-t, --type:
    switch between different types of color quantization:
      lin: linear scaling from 1 to maxvalue (default)
      log: logarithmic scaling from 1 to maxvalue 

-l, --locations:
    paint known locations below the actual data

-L, --legend:
    paint a legend for the colorscale with a specific height (default: 160)

-d, --description:
    paint a description above the legend

-T, --title:
    paint a title above the legend

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

--updatedb:
    update/initialize the maxmind database

EOS
exit 
end

# select parser
def select_parser(type)
  case type
  when "maxmind"
    GeoParser::MaxmindLocationParser.new
  when "hip"
    GeoParser::HIPCityParser.new
  when "generic"
    GeoParser::GeoParser.new
  when "ip"
    p = IPParser.new
    p.matcher = $matcher
    return p
  when "reverseip"
    p = ReverseIPParser.new
    p.matcher = $matcher
    return p
  end
end

# paint the locations in the light shadow
def paint_locations(image)
  puts "painting locations"
  c = 0
  before = Time.new
  # get the locations in small blocks (due to bug in mysql pkg)
  (0..3500).each do |i|
    $matcher.get_location(i*100,(i+1)*100-1).each do |l|
      image.coordinate(l[0].to_f,l[1].to_f,"#111")
      c += 1
      if c % 50000 == 0
        puts "Painted #{c} locations."
      end
    end
  end
  after = Time.new
  puts "Painted #{c} locations in #{(after-before)} seconds (#{(c/(after-before)).to_i}/sec)"
end

# Specify options
opts = GetoptLong.new(
  [ "--help", "-h", GetoptLong::NO_ARGUMENT ],
  [ "--output", "-o", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--input", "-i", GetoptLong::REQUIRED_ARGUMENT ],
  [ "--input-type", "-I", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--height", "-H", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--colormap", "-c", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--maxvalue", "-m", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--type", "-t", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--locations", "-l", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--title", "-T", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--description", "-d", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--host", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--port", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--dbname", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--user", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--pass", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--updatedb", GetoptLong::OPTIONAL_ARGUMENT ]
  )

# Show usage if not enough arguments given
usage if ARGV.length < 2

# Init unset options to default
$maxval = -1.0
$type = "log"
colors = nil
locations = false

height = 900
input = ""
itype = "generic"
output = ""

title = nil
desc = nil

dbhost = "localhost"
dbport = "3306"
db = "maxmind"
dbuser = "ipmatcher"
dbpass = ""
updatedb = false

# Parse options
opts.each do |opt, arg|
  case opt
  when "--help"
    usage
  when "--output"
    output = arg
  when "--input"
    if File.file?(arg)
      input = arg
    else 
      usage
    end
  when "--input-type"
    itype = arg
  when "--height"
    height = arg.to_i
  when "--colormap"
    if File.file?(arg) && File.extname(arg) == ".yml"
      colors = YAML::load(File.open(arg))
    else 
      usage
    end
  when "--maxvalue"
    $maxval = arg.to_f
  when "--type"
    # if arg in ["log", "lin"]
    $type = arg
  when "--locations"
    locations = true
  when "--title"
    title = arg
  when "--description"
    desc = arg
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
  when "--updatedb"
    updatedb = true
  end
end

# try to connect to the db
begin
  $matcher = Ipmatcher::MaxMindMatcher.new(dbhost,dbuser,dbpass,db)
  # update database if requested
  if updatedb
    $matcher.get_updates()
  end
rescue Exception => e
  if itype == "ip" or locations 
    puts "db access failed, but required. exiting."
    Process.exit
  else
    puts "db access failed, but not required. continueing."
  end
end

# Create image
image = EarthPainter::EarthImage.new(height, "black", output)
if locations
  paint_locations(image)
end
# parse file and create picture
parser = select_parser(itype)
parser.file = input
puts "start analyzing #{parser.file}"
c = 0
errors = 0
before = Time.new
parser.each do |d|
  c += 1
  if c % 10000 == 0
    puts "parsed #{c} entries."
  end
	begin
	  image.map(d[:lat],d[:lon],d[:val])
  rescue NoMethodError => e
    errors += 1
	  next
  end
end
after = Time.new
puts "Finished. #{c} entries in #{(after-before)} seconds (#{(c/(after-before)).to_i}/sec)"
puts "min value: #{image.min} - max value: #{image.max}"
puts "#{errors} occured (non-parsable lines or no coordinates)"
# render image
puts "start rendering #{image.name}"
if $maxval < 1
  cgrad = EarthPainter::ColorGradient.new(image.min, image.max)
else
  puts "Using #{$maxval} instead of #{image.max}"
  cgrad = EarthPainter::ColorGradient.new(image.min, $maxval)
end

image.draw(cgrad)
if title
  image.title(title)
end
if desc
  image.description(desc)
end

image.legend(cgrad)

image.write
puts "done"