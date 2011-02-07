require "rubygems"
require "RMagick"

# = Module for drawing nice geographic maps of huge amounts of data

module EarthPainter
  class EarthImage
    include Magick
    
    attr_reader :height, :width, :scale, :bg, :name, :gc, :canvas, :cyc
    attr_accessor :rr
    
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
      @canvas = Image.new(@width, @height) { self.background_color = @bg}

      @cyc = cycles
  		@rr = 0
    end
    
    # draw a single pixel on the map
    def point(lat, lon, color, opacity = 1.0)
      update
      x = (@width / 2 + lon * @scale).to_i
      y = (@height / 2 - lat * @scale).to_i
      @gc.fill_opacity(opacity)
      @gc.fill(color)
      @gc.point(x,y)
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