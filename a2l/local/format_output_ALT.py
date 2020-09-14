#!/usr/bin/python

import os, argparse
import sys


filename = sys.argv[1]

text = []
with open(filename, 'r') as f:
    for line in f.readlines():
        text.append(line.split(' ',1)[1].replace('\n',''))
    
text = ' '.join(text).replace('  ',' ')

with open(filename, 'w') as w:
    w.write(text)
