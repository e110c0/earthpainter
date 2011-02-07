require "rubygems"
require "RMagick"
include Magick

gc = Draw.new
gc.fill("white")
gc.fill_opacity(0.2)
canvas = Image.new(3600,1800) { self.background_color = "black"}

File.open("data/hip_ip4_city_lat_lng.csv").each{ |line|
  data = line.chomp.split(',')
  lat = (900 - data[2].to_f * 10).to_i
  lon = (data[3].to_f * 10 + 1800).to_i
  gc.point(lon,lat)
}
gc.draw(canvas)
canvas.write("images/hip_earthview.png")