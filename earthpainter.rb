# Copyright 2011 Dirk Haage. All rights reserved.
# This code is released under the BSD license, for details see the README file

require "rubygems"
require "RMagick"

# = Module for drawing nice geographic maps of huge amounts of data

module EarthPainter
  class EarthImage
    include Magick
    
    attr_reader :height, :width, :scale, :bg, :name, :gc, :canvas, :cyc
    attr_accessor :rr, :max, :min
    
    # height => INT picture height, width is derived from this (2x heigth)
    # bg => STRING Backgroundcolor
    # name => STRING Imagename
    
    def initialize( height = 1800,
                    bg = 'black',
                    name = 'earth.png',
                    cycles = 10000)
      @height = height
      @width = height*2
      @scale = height/180
      @bg = bg
      @name = name
      @gc = Draw.new
      @canvas = Image.new(@width, @height) { self.background_color = bg}
      
      @max = 0
      @min = 1/0.0
      @points = Hash.new
      
      @cyc = cycles
  		@rr = 0
    end
    
    # map a datapoint on a pixel on the canvas
    def map(lat, lon, count)
      x = (@width / 2 + lon * @scale).to_i.to_s
      y = (@height / 2 - lat * @scale).to_i.to_s
      begin
        @points[x][y] += count
      rescue Exception => e
        if @points[x] == nil
          @points[x] = Hash.new
        end
        @points[x][y] = count
      end
      # keep track of the highest/lowest count
      if @points[x][y] > @max
        @max = @points[x][y]
      end
      if @points[x][y] < @min
        @min = @points[x][y]
      end      
    end

    # draw a single pixel on the map
    def point(x, y, color)
      update
      @gc.fill(color)
      @gc.point(x,y)
    end
    
    # draw the full image
    def draw(cgrad)
      @points.each_key{ |x|
        @points[x].each_key{ |y|
          point(x.to_i,y.to_i,cgrad.get_color(@points[x][y]))
        }
      }
    end
  
  	# write out the image to disk finally
  	def write
  		@gc.draw(@canvas)
  		@canvas.write(@name)
  	end

    # Local private methods
  	# refresh the image, kill the current drawing context and create a new one
  	# This is done for performance reasons by default every 10000 drawn objects
  	def update
  	  # write out the image to get rid of overflows every cyc objects
  		if @rr >= @cyc
    		@gc.draw(@canvas)
    	  @gc = Draw.new
  			@rr = 0
  		else 
  			@rr += 1
  		end
  	end
  	
  	private :update

  end
  
  class ColorGradient
    include Magick
    
    attr_reader :colorcount, :type, :min, :max    
    attr_accessor :colors
    
    def initialize(min,
                  max,
                  colorcount = 80,
                  type = "log")
      @min = min
      @max = max
      @colorcount = colorcount
      @type = type
      @colors = {
         1 => "#00000f",  2 => "#00001f",  3 => "#00002f",  4 => "#00003f",
         5 => "#00004f",  6 => "#00005f",  7 => "#00006f",  8 => "#00007f",
         9 => "#00008f", 10 => "#00009f", 11 => "#0000af", 12 => "#0000bf",
        13 => "#0000cf", 14 => "#0000df", 15 => "#0000ef", 16 => "#0000ff",

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
      
      @base = 0
      @step = 0
      calc_colorstepping
    end

    # calculate the colorsteps depending on the min/max values and the 
    # number of colors
    # types so far: log, linear
    def calc_colorstepping
      if type == "log"
        @base = Math.log((@max-@min+2)**(1.0/@colorcount))
      elsif type == "linear"
        @step = (@max-@min+1)/@colorcount
      end
    end
    
    def reset_colors
      @colors = Hash.new
    end
    
    def set_color(no,color)
      @colors[no]=color
    end
    
    # calculate the colorlist based on the first and last color
    def calc_colorlist(first, last)
      f = first.gsub!(/#/,'').to_i(16)
      l = last.gsub!(/#/,'').to_i(16)
      step = ((l - f) / (@colorcount)).to_i
      c = 1
      while c <= @colorcount do
        @colors[c] = "#%06x" % (f + c * step)
        c += 1
      end
      puts @colors
    end

    def calc_colors()
    end
    
    def get_color(value)
      if type == "log"
        no = (1 + Math.log(value+1-@min)/@base).floor.to_i
        if colors[no] != nil
          return colors[no]
        else
          return colors[@colorcount]
        end
      end
    end
  end
end