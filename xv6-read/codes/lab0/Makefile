
CC = gcc
AS = gas
LD = ld

OBJCOPY = objcopy
OBJDUMP = objdump
QEMU = qemu-system-i386 

CFLAGS = -fno-pic -static -fno-builtin -fno-strict-aliasing -Wall -MD -ggdb -m32 -Werror -fno-omit-frame-pointer
#  -O2
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)

#ASFLAGS = -m32 -gdwarf-2 -Wa,-divide
LDFLAGS += -m $(shell $(LD) -V | grep elf_i386 2>/dev/null | head -n 1)

xv6.img: bootblock
	dd if=/dev/zero of=xv6.img count=10000
	dd if=bootblock of=xv6.img conv=notrunc
	#dd if=kernel of=xv6.img seek=1 conv=notrunc

bootblock: boot/bootasm.S boot/bootmain.c
	$(CC) $(CFLAGS) -fno-pic -O -nostdinc -I./include -c boot/bootmain.c
	$(CC) $(CFLAGS) -fno-pic -nostdinc -I./include -c boot/bootasm.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 -o bootblock.o bootasm.o bootmain.o
	$(OBJDUMP) -S bootblock.o > bootblock.asm
	$(OBJCOPY) -S -O binary -j .text bootblock.o bootblock
	perl ./sign.pl bootblock

qemu: xv6.img
	$(QEMU) -drive file=xv6.img,index=0,media=disk,format=raw -smp 1 -m 256

qemu-gdb: xv6.img
	$(QEMU) -drive file=xv6.img,index=0,media=disk,format=raw -smp 1 -m 256 -s -S


clean: 
	-rm -f *.d *.o  bootblock *.img *.asm

