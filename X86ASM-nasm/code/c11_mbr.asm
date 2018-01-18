;
; MBR, Prgram loader 
;
; 注意按照作者代码，将保护模式的代码段基地址设置为0x7c00，段限制设置为0x1FF，512字节
; 如果使用作者形式，这里不能定义vstart=0x7C00，否则段访问会出错
; 如果要编译成vstart=0x7c00，那么必须将代码段的描述符修改一下，比如基地址0，段限制64K 
SECTION mbr align=16 vstart=0x7C00
[bits 16]
    jmp near start    
            
start: 
    xor ax, ax   
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00
    
    mov ax, 0xb800
    mov es, ax
    xor bx, bx
    mov ah, 0x07
    mov al, 0x20
    mov cx, 2000
 cls:
    mov word [es:bx], ax
    add bx, 2 
    loop cls    
    

    mov ax, [gdt_base + 2] ; + 0x7c00
    mov dx, ax
    mov ax, [gdt_base]
    mov bx, 0x10
    div bx
    mov bx, dx
    
    push ds
    mov ds, ax
    ;descriptor 0
    mov dword [bx + 4*0], 0x0
    mov dword [bx + 4*1], 0x0
    
    ; descriptor 1
    mov dword [bx + 4*2], 0x0000FFFF
    mov dword [bx + 4*3], 0x00409800
    
    ; descriptor 2
    mov dword [bx + 4*4], 0x8000FFFF
    mov dword [bx + 4*5], 0x0040920b
    
    ; descriptor 3
    mov dword [bx + 4*6], 0x00007a00
    mov dword [bx + 4*7], 0x00409600
    
    pop ds
    mov word [gdt_size], 31 ; + 0x7c00
    
    lgdt [gdt_size]  ; + 0x7c00
    
    in al, 0x92     ; A20 Address Line
    or al, 0x02
    out 0x92, al
    
    cli      
    
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    
    jmp dword 0x0008:flush
    
    [bits 32]
flush:
    mov cx, 00000000000_10_000B ; data 0x10
    mov ds, cx
    
    mov byte [0x00], 'P'
    mov byte [0x02], 'r'
    mov byte [0x04], 'o'
    mov byte [0x06], 't'
    mov byte [0x08], 'e'
    mov byte [0x0a], 'c'
    mov byte [0x0c], 't'
    mov byte [0x0e], ' '
    mov byte [0x10], 'm'
    mov byte [0x12], 'o'
    mov byte [0x14], 'd'                                        
    mov byte [0x16], 'e'
    mov byte [0x18], ' '
    mov byte [0x1a], 'O'
    mov byte [0x1c], 'K'
    
    mov cx, 00000000000_11_000B
    mov ss, cx
    mov esp, 0x7c00
    
    mov ebp, esp
    push '.'
    sub ebp, 4
    cmp ebp, esp
    jnz ghlt
    pop eax
    mov [0x1e], al

ghlt:    
    hlt        

    gdt_size    dw  0
    gdt_base    dd  0x00007e00
    
    times 510 - ($-$$) db 0
    db 0x55, 0xaa