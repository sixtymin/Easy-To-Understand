
dd bs=512 count=1 if=.\c13_mbr.bin of=.\hd.img seek=0 skip=0
dd bs=512 count=12 if=.\c14_core.bin of=.\hd.img seek=1 skip=0
dd bs=512 count=4 if=.\c13_app.bin of=.\hd.img seek=20 skip=0
dd bs=512 count=2 if=.\diskdata.txt of=.\hd.img seek=30 skip=0