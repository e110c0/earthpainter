require "rubygems"
require "RMagick"
include Magick


ipcount = Hash.new

File.open("data/GeoLite_20110101/GeoLiteCity-Blocks.csv").each{ |line|
  data = line.chomp.split(',')
  data.each{ |i|
    i.gsub!(/"/,'')
  }
  begin
    #ipcount[data[2]] = data[1].to_i - data[0].to_i + 1 + ipcount[data[2]]
    ipcount[data[2]] += 1
  rescue Exception => e
    #ipcount[data[2]] = data[1].to_i - data[0].to_i + 1
    ipcount[data[2]] = 1
  end
}
puts "Finished counting IPs"

gc = Draw.new
gc.fill("white")
gc.fill_opacity(1.0)
canvas = Image.new(3600,1800) { self.background_color = "black"}

File.open("data/GeoLite_20110101/GeoLiteCity-Location.csv").each{ |line|
  data = line.chomp.split(',')
  lat = (900 - data[5].to_f * 10).to_i
  lon = (data[6].to_f * 10 + 1800).to_i
  begin
    opac = (1 + ipcount[data[0]] / 1) / 5.0
    if opac <= 1.0
      gc.fill_opacity(opac)
    else
      gc.fill_opacity(1.0)
    end
    gc.point(lon,lat)    
  rescue Exception => e
  end
}
gc.draw(canvas)
canvas.write("images/geolite_earthview_shades.png")