#!/usr/bin/python

import os, argparse, re
import sys, codecs

def main(filepath):

    ali = []
    with open(filepath,'r') as r:
        for line in r.readlines():
            if not '<UNK>' in line:
                ali.append(line)
    with open(filepath,'w') as w:
        for line in ali:
            w.write(line)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("filepath", type=str, help="Path to final output file")

    args = parser.parse_args()
    filepath = args.filepath

    main(filepath)        
