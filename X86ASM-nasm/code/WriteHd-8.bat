
dd bs=512 count=1 if=.\c08_mbr.bin of=.\hd.img seek=0 skip=0
dd bs=512 count=2 if=.\c08.bin of=.\hd.img seek=10 skip=0