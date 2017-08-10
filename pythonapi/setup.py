#!/usr/bin/env python
# -*- coding: utf-8 -*-

from setuptools import setup

setup(name='liner2',
	version='1.0.0',
	description='Python API for Liner2 tools',
	author="Michał Marcińczuk",
	author_email="michal.marcinczuk@pwr.wroc.pl",
	packages=[ 'liner2' ],
	package_data={},
	entry_points={
		'console_scripts': [
			'liner2ws = liner2.liner2ws:main'
		]
	}
)