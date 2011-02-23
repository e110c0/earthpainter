require "rubygems"
require "earthpainter"
require "geoparser"

image = EarthPainter::EarthImage.new(height = 900)
parser = GeoParser::HIPCityParser.new("../data/hip_ip4_city_lat_lng.csv")
puts parser.file
parser.each{ |d|
  image.map(d[:lat],d[:lon],d[:val])
}

colors = EarthPainter::ColorGradient.new(image.min, image.max/5)
image.draw(colors)
image.write