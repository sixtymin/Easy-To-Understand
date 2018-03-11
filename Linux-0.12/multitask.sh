#!/bin/bash

as86 -0 -a -o boot.o boot.S
ld86 -0 -s -o boot boot.o

dd bs=32 if=./bootsect of=./hd.img skip=1 conv=notrunc


