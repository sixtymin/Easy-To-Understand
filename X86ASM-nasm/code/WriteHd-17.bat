
dd bs=512 count=1 if=.\c17_mbr.bin of=.\hd.img seek=0 skip=0
dd bs=512 count=13 if=.\c17_core.bin of=.\hd.img seek=1 skip=0
dd bs=512 count=3 if=.\c17_app_1.bin of=.\hd.img seek=20 skip=0
dd bs=512 count=3 if=.\c17_app_2.bin of=.\hd.img seek=30 skip=0
rem dd bs=512 count=2 if=.\diskdata.txt of=.\hd.img seek=30 skip=0