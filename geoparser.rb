# Copyright 2011 Dirk Haage. All rights reserved.
# This code is released under the BSD license, for details see the README file
#
# = Description
# Basis to convert any data into coordinates:value form
#
# = Implementation
# Using GeoParser means that the class using it simply implements the methods
# string_to_data STRING => HASH
# data_to_string HASH => STRING
# Where HASH contains at least
# {:lat => FLOAT, :lon => FLOAT, :val => FLOAT}

module  GeoParser
  
  # Exception handling for trying to parse if the file is not set yet
  class FileMissingError < RuntimeError
  end
  
  # Base class for geo parser
  class Base
    
    # Make the parser an enumerable object, to allow line by line handling
    include Enumerable
    # The currently parsed file
    attr_accessor :file

    def initialize(file=nil)
      @file = file if file
    end
    
    # Overwriting each to enable error handling as well as line by line parsing
    def each
      raise FileMissingError, "File not set" unless @file
      begin
        f = File.open(@file, "r")
        f.each do |l|
          yield string_to_data l
        end
      rescue => err
        err
      ensure
        f.close
      end
    end
    
  end
  
  # Parser for the HostIP data files
  class HIPCityParser < Base
    
    def string_to_data(string)
      data = string.chomp.split(',')
      {:lat => data[2].to_f, :lon => data[3].to_f, :val => 1, :network => data[0].to_i, :city => data[1]}
    end
    
    def data_to_string(data)
      "#{data[:network]},#{data[:city]},#{data[:lat]},#{data[:lon]}".chomp
    end
    
  end
  
  # Parser for the MaxMind Location files
  class MaxmindLocationParser < Base
    def string_to_data(string)
      data = string.chomp.split(',')
      {:lat => data[5].to_f, :lon => data[6].to_f, :val => 1, 
        :location => data[0].to_i, :country => data[1], :state => data[2],
        :city => data[3], :postcode => data[4]}

    end
    
    def data_to_string(data)
      "#{data[:id]},#{data[:country]},#{data[:state]},#{data[:city]},
       #{data[:postcode]},#{data[:lat]},#{data[:lon]}".chomp
    end
  end
  
end