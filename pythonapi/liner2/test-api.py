#!/usr/bin/env python
# -*- coding: utf-8 -*-

from liner2.api import Liner2WsApi
import sys

wsdl = "http://188.124.184.105/nerws/ws/nerws.wsdl"

liner2 = Liner2WsApi(wsdl)

text = '''Z kolei prasa w Niemczech ocenia, że prezydent Rosji nie ma pomysłu jak pomóc gospodarce swojego kraju. 
Pokazało to wczorajsze wystąpienie Władimira Putina na dorocznej konferencji prasowej - piszą komentatorzy niemieckich gazet. 
Jak czytamy w dzienniku "Sueddeutsche Zeitung", wczoraj po raz kolejny widać było, że Putin nie ma żadnego pomysłu jak postawić 
rosyjską gospodarkę na nogi. Należy się nawet obawiać, że ma to dla niego drugorzędne znaczenie. 
Patetyczny patriotyzm i opowieści o rosyjskim niedźwiedziu, który nie da się poskromić, spełniają bowiem swoją funkcję. 
Naród łączy się z prezydentem. Komentator "Frankfurter Allgemeine Zeitung" pisze z kolei, 
że Putin nie widzi związku między swoim czynami a obecnymi problemami. Rosyjski prezydent przekonuje, 
że winę za kryzys ponoszą czynniki zewnętrzne. Komentator gazety nazywa też absurdalnym stwierdzenie Putina, 
że Rosja nie płaci ceny za aneksję Krymu, tylko za dążenie do utrzymania się jako naród, cywilizacja i państwo.'''

text = sys.stdin.readlines()

print liner2.analyse(text, "plain:wcrft", "tuples", "names")