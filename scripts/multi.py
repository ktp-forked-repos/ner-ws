#! /usr/bin/python
# -*- coding: utf-8 -*-

# NER-WebService performance measurer
# sends many requests and measures average processing time
# author: Maciej Janicki

import codecs
import sys
from optparse import OptionParser
from threading import Thread
import random
import time
import warnings
with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    from ZSI.ServiceProxy import ServiceProxy

script_usage = ""
service_wsdl = "http://nlp1.synat.pcss.pl/nerws/nerws.wsdl"
interval = 0.1
times = []

def process_request(idx, options, text, service):
    global times
    #time.sleep(random.random())
    state = 0
    r = None
    times[idx] = time.time()
    r = service.Annotate(input_format = options.input_format.upper(), \
                             output_format = 'IOB', text = text)
    #print "Request", idx, "sent"
    state = int(r['response']['status'])
    token = r['response']['msg']
    while state < 3:
        time.sleep(interval)
        r = service.GetResult(token = token)
        state = int(r['response']['status'])
    if state == 4:
        print "Error:", r['response']['msg']
    times[idx] = time.time() - times[idx]

def run(options):
    global times
    text = ""
    if options.directory is None:
        with codecs.open(options.input_file, "r", "utf-8") as f:
            text = f.read()
    elif not options.directory.endswith("/"):
        options.directory += "/"
    service = ServiceProxy(wsdl=service_wsdl)
    times = [None] * options.num
    threads = [None] * options.num

    sum_time = 0
    total_time = time.time()
    for i in range(0, options.num):
        if options.directory is not None:
            filename = options.directory + options.input_file.replace("NN", str(i+1))
            with codecs.open(filename, "r", "utf-8") as f:
                text = f.read()
        threads[i] = Thread(target = process_request, \
                                args = (i, options, text, service))
        threads[i].start()
    for i in range(0, options.num):
        threads[i].join()
        sum_time += times[i]
	
    total_time = time.time() - total_time
    print "Requests sent:", options.num
    #print "Successfully processed:", num_succesful
    #print "Times:", times
    print "Average time:", sum_time / options.num, "s"
    print "Total time:", total_time, "s"
    print "Time / request:", total_time / options.num, "s"

def _argument_parser(args):
    parser = OptionParser(usage = script_usage, version = "%prog 0.1")
    
    parser.add_option('-i', '--input-format', action = "store", \
                          type = "string", dest = "input_format", default = "iob", \
                          help = "input file format")
    parser.add_option('-d', '--directory', action = "store", \
                          type = "string", dest = "directory", default = None, \
                          help = "directory with input files")
    parser.add_option('-f', '--file', action = "store", \
                          type = "string", dest = "input_file", default = None, \
                          help = "input file path")
    parser.add_option('-n', '--num', action = "store", \
                          type = "int", dest = "num", help = "number of requests to send")
    (options, args) = parser.parse_args(args)
    return (options, args, parser)

def main(args):
    options, argv, parser = _argument_parser(args)
    run(options)

if __name__ == '__main__':
    main(sys.argv[1:])
