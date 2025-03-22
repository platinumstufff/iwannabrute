#Copyright (c) 2020, @mcg29_

#!/usr/local/bin/python3

import os
import sys

if __name__ == "__main__":
	args = sys.argv
	if len(args) < 3:
		print("Usage: kcache.raw kcache.patched")
		sys.exit(0)
	patched = open(args[2], "rb").read()
	original = open(args[1], "rb").read()
	lenP = len(patched)
	lenO = len(original)
	if lenP != lenO:
		print("size does not match, can't compare files! exiting...")
		sys.exit(1)
	diff = []
	for i in range(lenO):
		originalByte = original[i]
		patchedByte = patched[i]
		if originalByte != patchedByte:
			diff.append([hex(i),hex(originalByte), hex(patchedByte)])	
	diffFile = open('kc.bpatch', 'w+')
	diffFile.write('#AMFI\n\n')
	for d in diff:
		data = str(d[0]) + " " + (str(d[1])) + " " + (str(d[2]))
		diffFile.write(data+ '\n')
		print(data)
	
