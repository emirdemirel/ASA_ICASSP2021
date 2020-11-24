#!/usr/bin/python

import sys

input_file = sys.argv[1]
output_file = sys.argv[2]

ali = []
with open(input_file,'r') as r:
    for line in r.readlines():
        ali.append(line.split(' ')[2] + ' ' + str(float(line.split(' ')[2]) + float(line.split(' ')[3])) + ' ' + line.split(' ')[4].split('_')[0])
    rec_id = line.split('_')[0]    


with open(output_file,'w') as w:
    for line in ali:
        w.write(line + '\n')

