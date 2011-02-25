# Copyright 2011 Dirk Haage. All rights reserved.
# This code is released under the BSD license, for details see the README file
require 'rubygems'
require 'ipmatcher'
require 'geoparser'

# parser for ip data
# data format is:
# ip [val]
# missing values are set to 1
# example:
# 10.0.17.1   123
# 10.0.23.11  456
# 12.13.14.15
class IPParser < GeoParser::Base
  
  attr_accessor :matcher
  
  def initiliaze(file = nil, ipmatcher = nil)
    @matcher = ipmatcher if ipmatcher
  end
  
  def string_to_data(string)
    data = string.chomp.split(' ')
    if data.length >0
      loc = @matcher.get_coordinates(data[0])
      if loc
        if data.length == 1
          return {:lat => loc[0].to_f, :lon => loc[1].to_f, :val => 1}
        else
          return {:lat => loc[0].to_f, :lon => loc[1].to_f, :val => data[1].to_f, :ip => data[0]}
        end
      end
    end
    return nil
  end
  
  def data_to_string(data)
    begin
      "#{data[:ip]} #{data[:val]}".chomp      
    rescue Exception => e
      "#{data[:ip]}".chomp      
    end
    
  end
end

# parser for reversed ip data
# data format is:
# val ip
# example:
# 1234 10.0.17.1
#  123 10.0.23.11
class ReverseIPParser < GeoParser::Base

  attr_accessor :matcher
  
  def initiliaze(file = nil, ipmatcher = nil)
    @matcher = ipmatcher if ipmatcher
  end
  
  def string_to_data(string)
    data = string.chomp.split(' ')
    loc = @matcher.get_coordinates(data[1])
    {:lat => loc[0].to_f, :lon => loc[1].to_f, :val => data[0], :ip => data[1]}
  end
  
  def data_to_string(data)
    "#{data[:val]} #{data[:ip]}".chomp
  end
  
end
