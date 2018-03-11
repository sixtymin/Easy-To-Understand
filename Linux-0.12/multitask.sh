#!/bin/bash

as86 -0 -a -o boot.o boot.S
ld86 -0 -s -o boot boot.o

dd bs=32 if=./boot of=./hd.img skip=1 conv=notrunc

as -o head.o head.S
ld -m elf_i386 -Ttext 0 -e startup_32 -s -x -M -o system head.o

objcopy -O binary system head

dd bs=512 if=./head of=./hd.img skip=0 seek=1 conv=notrunc
