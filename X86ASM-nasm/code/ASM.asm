mov ax, 0xb800
mov ds, ax
mov byte [0x00], 'A'
mov byte [0x02], 'S'
mov byte [0x04], 'M'

jmp $

times 510 - ($ - $$) db 0
db 0x55, 0xaa