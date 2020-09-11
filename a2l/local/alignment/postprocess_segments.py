#!/usr/bin/python

import os, sys

input_segments=sys.argv[1]
merge_end_time=sys.argv[2]

segments = []
with open(input_segments,'r') as f:
    for line in f.readlines():
        segments.append(line.replace('\n',''))

for i in range(len(segments)):
    segments[i] = segments[i].split(' ')
    segments[i][2] = float(segments[i][2])

segments = sorted(segments, key=lambda item_key: item_key[2])

if merge_end_time == True:
    segs=[segments[0][0] + ' ' + segments[0][1] + ' ' + str(segments[0][2]) + ' ' + segments[0][3]]
    for i in range(1,len(segments)):
        segs.append(segments[i][0] + ' ' + segments[i][1] + ' ' + str(segments[i-1][3]) + ' ' + str(segments[i][3]))
else:
    segs=[]
    for i in range(len(segments)-1):
        segs.append(segments[i][0] + ' ' + segments[i][1] + ' ' + str(segments[i][2]) + ' ' + str(segments[i+1][2]))
    segs.append(segments[-1][0] + ' ' + segments[-1][1] + ' ' + str(segments[-1][2]) + ' ' + str(segments[-1][3]))
with open(input_segments,'w') as w:
    for line in segs:
        w.write(line + '\n')
