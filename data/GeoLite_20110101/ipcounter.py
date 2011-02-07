#!/usr/bin/env python
''' count all IPs in a maxmind dataset and calculate the number of IPs per Geolocation'''

import sys

def calcColor(i):
	color = (i / 256) + 16
	if color < 256:
		return color
	else:
		return 255

f = open('GeoLiteCity-Blocks.csv', 'r')

ipcount = {}

for line in f:
	if line[0] == '"':
		line = line.strip()
		start,end,location = [int(i.strip('"')) for i in line.split(",")]
		try:
			ipcount[location] = ipcount[location] + end - start + 1
		except KeyError:
			ipcount[location] = end - start + 1
f.close()

print 'Finished parsing City-Block'

f = open("GeoLiteCity-Location.csv", 'r')

locations = {}
for line in f:
	try:
		line = line.strip()
		locId,country,region,city,postalCode,latitude,longitude,metroCode,areaCode = [i.strip('"') for i in line.split(",")]
		locations[int(locId)] = (int(float(latitude)*10)+900, int(float(longitude)*10)+1800)
		#print int(locId), " : ", locations[int(locId)]
	except ValueError:
		pass

print 'Finished parsing Locations'

loccount = {}
for i in ipcount:
	loccount[i] = (locations[i][0],locations[i][1],calcColor(ipcount[i]))

print loccount

#create canvas 3600x1800px

#print each pixel

# set color


# render image


