require "rubygems"
require "earthpainter"

image = EarthPainter::EarthImage.new(height = 1200)

File.open("data/hip_ip4_city_lat_lng.csv").each{ |line|
  data = line.chomp.split(',')
  image.point(data[2].to_f,data[3].to_f,"white", 0.1)
}
image.write