require "rubygems"
require "./earthpainter.rb"

image = EarthPainter::EarthImage.new(height = 3600)

File.open("data/GeoLite_20110101/GeoLiteCity-Location.csv").each{ |line|
  data = line.chomp.split(',')
  image.map(data[5].to_f,data[6].to_f,1)
}
puts image.max
puts image.min
image.draw
image.write