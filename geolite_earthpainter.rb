require "rubygems"
require "./earthpainter.rb"

image = EarthPainter::EarthImage.new(900)

File.open("data/GeoLite_20110101/GeoLiteCity-Location.csv").each{ |line|
  data = line.chomp.split(',')
  image.map(data[5].to_f,data[6].to_f,1)
}
colors = EarthPainter::ColorGradient.new(image.min, image.max, 80)
colors.colors = {
  1 => "#00000f", 2 => "#00001f", 3 => "#00002f", 4 => "#00003f",
  5 => "#00004f", 6 => "#00005f", 7 => "#00006f", 8 => "#00007f",
  9 => "#00008f", 10 => "#00009f", 11  => "#0000af", 12 => "#000bf",
  13 => "#0000cf", 14 => "#0000df", 15 => "#0000ef", 16 => "#0000ff00",

  17 => "#000fff", 18 => "#001fff", 19 => "#002fff", 20 => "#003fff",
  21 => "#004fff", 22 => "#005fff", 23 => "#006fff", 24 => "#007fff",
  25 => "#008fff", 26 => "#009fff", 27 => "#00afff", 28 => "#00bfff",
  29 => "#00cfff", 30 => "#00dfff", 31 => "#00efff", 32 => "#00ffff",

  33 => "#00ffef", 34 => "#00ffdf", 35 => "#00ffcf", 36 => "#00ffbf",
  37 => "#00ffaf", 38 => "#00ff9f", 39 => "#00ff8f", 40 => "#00ff7f",
  41 => "#00ff6f", 42 => "#00ff5f", 43 => "#00ff4f", 44 => "#00ff3f",
  45 => "#00ff2f", 46 => "#00ff1f", 47 => "#00ff0f", 48 => "#00ff00",

  49 => "#0fff00", 50 => "#1fff00", 51 => "#2fff00", 52 => "#3fff00",
  53 => "#4fff00", 54 => "#5fff00", 55 => "#6fff00", 56 => "#7fff00",
  57 => "#8fff00", 58 => "#9fff00", 59 => "#afff00", 60 => "#bfff00",
  61 => "#cfff00", 62 => "#dfff00", 63 => "#efff00", 64  => "#ffff00",

  65 => "#ffef00", 66 => "#ffdf00", 67 => "#ffcf00", 68 => "#ffbf00",
  69 => "#ffaf00", 70 => "#ff9f00", 71 => "#ff8f00", 72 => "#ff7f00",
  73 => "#ff6f00", 74 => "#ff5f00", 75 => "#ff4f00", 76 => "#ff3f00",
  77 => "#ff2f00", 78 => "#ff1f00", 79 => "#ff0f00", 80 => "#ff0000"
}
image.draw(colors)
image.write