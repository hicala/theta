#!/usr/bin/python

# Custom settings.-
path = "/opt/SystemBackup"
name = path + "/data.xml"

# Load packages.-
import xml.etree.ElementTree as ET
import os
import sys
sys.path.append('/opt/SystemBackup')
from models import * 
os.system('clear')

# Load XML to memory.-
tree = ET.parse(name)
root = tree.getroot()

# Load handlers.-
HANDLERS = {}
for h in root.findall('handlers')[0].findall('h'):
	try: 
		name = h.attrib['name']
		b    = Backup()
		b.setType(h.attrib['type'].upper())
		b.setDir(h.attrib['location'])
		if h.attrib['password']:
			b.compress(h.attrib['password'])
		HANDLERS[name] = b
	except Exception as e:
		print "Error while loading %s!! " % name 
		print e

# Load sources.-
SOURCES = []
for s in root.findall('source'):
	dict = { 'handlers':[], 'files':[], }	
	for h in s.findall('handler'):
		print h.text
		dict['handlers'].append(h.text)
	for f in s.findall('dir'):
		dict['files'].append(f.text)
	SOURCES.append(dict)

# Combine Handlers and Sources and create a backup.-
for s in SOURCES:

	# For each handler.-
	for h in s['handlers']:
		if h in HANDLERS.keys():
			backup = HANDLERS[h]
		
			# For each file.-
			backup.clear()
			for f in s['files']:
				backup.add(f)

			# Compile and run.-
			backup.compile()
			backup.run()

			# End.-
			print backup.NAME
				
