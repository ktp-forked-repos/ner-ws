#! /usr/bin/python
# -*- coding: utf-8 -*-

# author: Michał Marcińczuk

import codecs
import time
import warnings
with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    from ZSI.ServiceProxy import ServiceProxy

class Liner2WsApi:

    def __init__(self, wsdl):
        self.wsdl = wsdl
        self.service = ServiceProxy(wsdl=wsdl, force=True)

    def _read_input(self, input_file):
        with codecs.open(input_file, "r", "utf-8") as f:
            return f.read()

    def _write_output(self, text, output_file):
        with codecs.open(output_file, "w+", "utf-8") as f:
            f.write(text)

    def analyse(self, text, input_format, output_format, model):
        r = self.service.Annotate(input_format = input_format, 
                             output_format = output_format,
                             model = model, 
                             text = text)
        token = r['response']['msg']
        step = 0.1
        while int(r['response']['status']) not in (3, 4):
            time.sleep(step)
            r = self.service.GetResult(token = token)
            # print r
        status = int(r['response']['status'])
        if status == 3:
            result_text = r['response']['msg']
            if not isinstance(result_text, unicode):
                result_text = unicode(result_text, "utf-8")
            return result_text
        elif status == 4:
            raise Exception("Server error:", r['response']['msg'])
           
    def analyseCcl(self, text):
    	return self.analyse("ccl", "ccl", text)

    def analyseCclFile(self, input_file, output_file):
        text = self._read_input(input_file)
        text = self.analyseCcl(text)
        self._write_output(text, output_file)