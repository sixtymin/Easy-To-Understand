; 没有指定程序起始地址，则默认从地址 0x00000000 上开始

    jmp near start
    
    string db 'L', 0x07, 'a', 0x07, 'b', 0x07, 'l', 0x07, 'e', 0x07, ' ', 0x07, 'o', 0x07,\
    'f', 0x07, 'f', 0x07, 's', 0x07, 'e', 0x07, 't', 0x07, ':', 0x07
    number db 0, 0, 0, 0, 0
    
start: 
    mov ax, 0xB800    ; 视频缓存起始地址，0x0B800 
    mov es, ax
    mov ax, 0x07C0
    mov ds, ax
    
    cld
    mov si, string
    xor di, di
    
    mov cx, number
    sub cx, string
    rep movsb
    ; mov cx, (number-string)/2
    ; rep movsw

    mov ax, number
    mov bx, 10
    
    mov si, number
    mov cx, 5     
digit:
    xor dx, dx
    div bx
    mov [si], dl
    inc si
    loop digit
    
    mov bx, number
    mov ah, 0x04
    mov si, 4
show:
    mov al, byte [bx + si]
    or ax, 0x30
    mov word [es:di], ax
    add di, 2
    dec si
    jns show
    
    mov byte [es:di], 'd'
    inc di
    mov byte [es:di], 0x04
    
infi:
    jmp near infi                 
    
    times 510 - ($-$$) db 0
    db 0x55, 0xaa