
    mov ax, 0xB800
    mov es, ax
    
    mov byte [es:0x00], 'L'
    mov byte [es:0x01], 0x07
    mov byte [es:0x02], 'a'
    mov byte [es:0x03], 0x07
    mov byte [es:0x04], 'b'
    mov byte [es:0x05], 0x07
    mov byte [es:0x06], 'l'
    mov byte [es:0x07], 0x07
    mov byte [es:0x08], 'e'
    mov byte [es:0x09], 0x07
    mov byte [es:0x0A], ' '
    mov byte [es:0x0B], 0x07
    mov byte [es:0x0C], 'o'
    mov byte [es:0x0D], 0x07
    mov byte [es:0x0E], 'f'
    mov byte [es:0x0F], 0x07
    mov byte [es:0x10], 'f'
    mov byte [es:0x11], 0x07
    mov byte [es:0x12], 's'
    mov byte [es:0x13], 0x07
    mov byte [es:0x14], 'e'
    mov byte [es:0x15], 0x07
    mov byte [es:0x16], 't'
    mov byte [es:0x17], 0x07
    mov byte [es:0x18], ':'
    mov byte [es:0x19], 0x07
    mov byte [es:0x1A], ' '
    mov byte [es:0x1B], 0x07
    
    mov ax, number
    mov bx, 10
    
    mov cx, cs
    mov ds, cx
    
    mov dx, 0
    div bx
    mov [0x7c00 + number + 0x00], dl    
    xor dx, dx
    div bx
    mov [0x7c00 + number + 0x01], dl    
    xor dx, dx
    div bx
    mov [0x7c00 + number + 0x02], dl    
    xor dx, dx
    div bx
    mov [0x7c00 + number + 0x03], dl    
    xor dx, dx
    div bx
    mov [0x7c00 + number + 0x04], dl
        
    mov al, [0x7c00 + number + 0x04]
    add al, 0x30
    mov byte [es:0x1C], al
    mov byte [es:0x1D], 0x04
    mov al, [0x7c00 + number + 0x03]
    add al, 0x30
    mov byte [es:0x1E], al
    mov byte [es:0x1F], 0x04
    mov al, [0x7c00 + number + 0x02]
    add al, 0x30
    mov byte [es:0x20], al
    mov byte [es:0x21], 0x04
    mov al, [0x7c00 + number + 0x01]
    add al, 0x30
    mov byte [es:0x22], al
    mov byte [es:0x23], 0x04
    mov al, [0x7c00 + number + 0x00]
    add al, 0x30
    mov byte [es:0x24], al
    mov byte [es:0x25], 0x04       

    mov byte [es:0x26], 'D'
    mov byte [es:0x27], 0x04
infi:
    jmp near infi
             
    number db 0, 0, 0, 0, 0
    
    times 510 - ($-$$) db 0
    db 0x55, 0xaa
