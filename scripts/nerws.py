#! /usr/bin/python
# -*- coding: utf-8 -*-

# NER-WebService example
# author: Maciej Janicki

import codecs
import sys
from optparse import OptionParser
import time
import warnings
with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    from ZSI.ServiceProxy import ServiceProxy

script_usage = ""
service_wsdl = "http://nlp1.synat.pcss.pl/nerws/nerws.wsdl"
#service_wsdl = "http://156.17.129.135/nerws/ws/nerws.wsdl"
#service_wsdl = "http://188.124.184.105/ner/ws/nerws.wsdl"

def read_input(options):
    if options.input_file is not None:
        with codecs.open(options.input_file, "r", "utf-8") as f:
            return f.read()
    else:    
        return sys.stdin.read()

def write_output(text, processing_time, options):
    if options.output_file is not None:
        with codecs.open(options.output_file, "w+", "utf-8") as f:
            f.write(text)
            print "Processing time:", processing_time, "s"
    else:
        print text.encode("utf-8")

def run(options):
    text = read_input(options)
    service = ServiceProxy(wsdl=service_wsdl)
    r = service.Annotate(input_format = options.input_format.upper(), 
                         output_format = options.output_format.upper(), 
                         text = text)
    token = r['response']['msg']
    step = 0.1
    processing_time = 0
    while int(r['response']['status']) not in (3, 4):
        time.sleep(step)
        processing_time += step
        r = service.GetResult(token = token)
        # print r
    status = int(r['response']['status'])
    if status == 3:
        result_text = r['response']['msg']
        if not isinstance(result_text, unicode): # ???
            result_text = unicode(result_text, "utf-8")
        write_output(result_text, processing_time, options)
    elif status == 4:
        print "Server error:", r['response']['msg']

def _argument_parser(args):
    parser = OptionParser(usage = script_usage, version = "%prog 0.1")
    
    parser.add_option('-i', '--input-format', action = "store", \
                          type = "string", dest = "input_format", default = "iob", \
                          help = "input file format")
    parser.add_option('-o', '--output-format', action = "store", \
                          type = "string", dest = "output_format", default = "iob", \
                          help = "output file format")
    parser.add_option('-f', '--file', action = "store", \
                          type = "string", dest = "input_file", default = None, \
                          help = "input file path")
    parser.add_option('-t', '--target', action = "store", \
                          type = "string", dest = "output_file", default = None, \
                          help = "output file path")
    (options, args) = parser.parse_args(args)
    return (options, args, parser)

def main(args):
    options, argv, parser = _argument_parser(args)
    run(options)

if __name__ == '__main__':
    main(sys.argv[1:])
