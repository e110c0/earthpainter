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
      # keep track of the highest count
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
                  colorcount = 15,
                  type = "log")
      @min = min
      @max = max
      @colorcount = colorcount
      @type = type
      @colors = Hash.new
      
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
        puts no
        colors[no]
      end
    end
  end
end