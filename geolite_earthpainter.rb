require "rubygems"
require "earthpainter"

image = EarthPainter::EarthImage.new(height = 1200)

File.open("data/GeoLite_20110101/GeoLiteCity-Location.csv").each{ |line|
  data = line.chomp.split(',')
  image.point(data[5].to_f,data[6].to_f,"white", 0.1)
}
image.write