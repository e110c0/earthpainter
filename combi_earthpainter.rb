require "rubygems"
require "RMagick"
include Magick

gc = Draw.new
gc.fill("white")
gc.fill_opacity(1.0)
canvas = Image.new(18000,9000) { self.background_color = "black"}

# draw locations
File.open("data/GeoLite_20110101/GeoLiteCity-Location.csv").each{ |line|
  data = line.chomp.split(',')
  lat = (4500 - data[5].to_f * 50).to_i
  lon = (data[6].to_f * 50 + 9000).to_i
  gc.point(lon,lat)
}
gc.draw(canvas)

# draw maxmind data
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
gc.fill("blue")
gc.fill_opacity(0.2)

File.open("data/GeoLite_20110101/GeoLiteCity-Location.csv").each{ |line|
  data = line.chomp.split(',')
  lat = (4500 - data[5].to_f * 50).to_i
  lon = (data[6].to_f * 50 + 9000).to_i
  begin
    opac = (1 + ipcount[data[0]] / 1) / 2.0
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

# draw hostip data
gc = Draw.new
gc.fill("red")
gc.fill_opacity(0.5)

File.open("data/hip_ip4_city_lat_lng.csv").each{ |line|
  data = line.chomp.split(',')
  lat = (4500 - data[2].to_f * 50).to_i
  lon = (data[3].to_f * 50 + 9000).to_i
  gc.point(lon,lat)
}
gc.draw(canvas)

# write image
canvas.write("images/combi_earthview_big.png")
