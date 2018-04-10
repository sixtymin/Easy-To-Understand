#!/bin/bash

as86 -0 -a -o bootsect.o bootsect.S
ld86 -0 -s -o bootsect bootsect.o

dd bs=32 if=./bootsect of=./hd.img skip=1 conv=notrunc
