# Copyright 2011 Dirk Haage. All rights reserved.
# This code is released under the BSD license, for details see the README file

require "rubygems"
require "earthpainter"

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

image = EarthPainter::EarthImage.new(height = 1200)

File.open("data/GeoLite_20110101/GeoLiteCity-Location.csv").each{ |line|
  data = line.chomp.split(',')
  lat = (900 - data[5].to_f * 10).to_i
  lon = (data[6].to_f * 10 + 1800).to_i
  begin
    opac = (1 + ipcount[data[0]] / 1) / 10.0
    if opac <= 1.0
      image.point(data[5].to_f,data[6].to_f,"white", opac)
    else
      image.point(data[5].to_f,data[6].to_f,"white")
    end
  rescue Exception => e
  end
}
image.write