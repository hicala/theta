#!/usr/bin/python
from datetime import * 
import os
import sys
import subprocess
import re

# Example:
# b = Backup()
# b.setType("LOCAL")
# b.setDir('/backup')
# b.compress('my_password')
# b.add('/tmp/bootstrap') 
# b.compile()
# b.run()
class Backup:

	# Available backup types.-
	BACKUP_TYPES = ["LOCAL","MOUNT","FTP",]
	
	# Simple init method with empty elements.-
	# TYPE	  = Type of backup among ("LOCAL","MOUNT","FTP")
	# PASW 	  = Password for the compressed file.-
	# TS   	  = Timestamp.-
	# DIR	  = Destination directory.-
	# FILES   = List of files to be compressed.-
	# CMD	  = Command to be executed.-
	# NAME    = Full name of the compressed file.-
	def __init__(self):
		self.PASW  	= None
		self.TYPE	= "LOCAL"
		self.DIR	= "/tmp"
		self.TS		= datetime.now().strftime("%Y-%m-%d-%H:%M:%S")
		self.FILES 	= []
		self.CMD   	= ""
		self.NAME	= ""

	# Checks File System usage
	# float self.df()
	def df(self):
		df = subprocess.Popen(["df","-HP",self.DIR], stdout=subprocess.PIPE)
		output = df.communicate()[0]
		arr  = output.split("\n")[1].split()	
		size = arr[4]
		# print "Usage: %s" % size
		size = re.sub('%','',size) 
		return float(size)

	# Compiles files into self.CMD.-
	# String self.compile()
	def compile(self):
		if len(self.FILES)>0:
			self.NAME = "%sbackup-%s.zip" % (self.DIR,self.TS)
			files = ' '.join(self.FILES)	
			if self.PASW: 	pasw = "-P '%s'" % self.PASW
			else:		pasw = ""
			self.CMD = "zip -r %s %s %s" % (self.NAME,pasw,files)
			print "Command: %s " % self.CMD 
			return self.CMD 
		else:
			return ""

	# Runs the self.CMD command
	# null self.run()
	def run(self):
		if not self.CMD:
			raise Exception("Need compilation first!")
		else:
			os.system(self.CMD)

	# Adds a file to the self.FILES array.-
	# null self.add(file)
	def add(self,file):
		if not os.path.exists(file):
			raise Exception("File %s does not exist" % file)
		elif not os.access(file, os.R_OK):
			raise Exception("Can not read file %s" % file)
		else:
			self.FILES.append(file)

	# Remove a file from the self.FILEs array.-
	# null self.remove(file)
	def remove(self,file):
		self.FILES.remove(file)

	# This adds a password to the zip command.-
	# null self.compress(password)
	def compress(self,pasword):
		self.PASW = pasword

	# This removes the password from the zip command.-
	# null self.uncompress()
	def uncompress(self):
		self.PASW = None

	# Set the zip destination.-
	# null setDir(d)
	def setDir(self,d):
		self.DIR = d 
		if not os.path.exists(self.DIR):
			raise Exception("%s does not exist" % self.DIR)
		elif os.path.isfile(self.DIR):
			raise Exception("%s is not " % self.DIR)
		elif not os.access(self.DIR, os.W_OK):
			raise Exception("Can not write to %s" % self.DIR)
		elif self.df()>70:
			raise Exception("File System %s is above 70" % self.DIR)

	# Set the backup type.-
	# null setType(t)
	def setType(self,t):
		if t in self.BACKUP_TYPES:
			self.TYPE = t
		else:
			raise Exception("Type %s is not supported " % t)

	# Clear all files in this backup
	# null clear()
	def clear(self):
		self.FILES = []

