#!/usr/bin/env python
# -*- coding: utf-8 -*-

from liner2.api import Liner2WsApi
import sys

#--------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------
def main(args = None):
	wsdl = "http://188.124.184.105/nerws/ws/nerws.wsdl"	
	text = sys.stdin.readlines()	
	print Liner2WsApi(wsdl).analyse(text, "plain:wcrft", "tuples", "names")