require "rubygems"
require "earthpainter"
require "geoparser"

image = EarthPainter::EarthImage.new(1280)

parser = GeoParser::MaxmindLocationParser.new("../data/GeoLite_20110101/GeoLiteCity-Location.csv")
puts parser.file
parser.each{ |d|
  image.map(d[:lat],d[:lon],d[:val])
}

colors = EarthPainter::ColorGradient.new(image.min, image.max/200)
image.draw(colors)
image.write