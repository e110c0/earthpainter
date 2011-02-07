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
    def point(x, y, color, opacity = 1.0)
      update
      @gc.fill(color)
      @gc.fill_opacity(opacity)
      @gc.point(x,y)
    end
    
    # draw the full image
    def draw
      @points.each_key{ |x|
        @points[x].each_key{ |y|
          point(x.to_i,y.to_i,"white",1.0)
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
  end
end