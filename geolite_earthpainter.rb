require "rubygems"
require "RMagick"
include Magick

gc = Draw.new
gc.fill("white")
gc.fill_opacity(1.0)
canvas = Image.new(3600,1800) { self.background_color = "black"}

File.open("data/GeoLite_20110101/GeoLiteCity-Location.csv").each{ |line|
  data = line.chomp.split(',')
  lat = (900 - data[5].to_f * 10).to_i
  lon = (data[6].to_f * 10 + 1800).to_i
  gc.point(lon,lat)
}
gc.draw(canvas)
canvas.write("images/geolite_earthview_simple.png")