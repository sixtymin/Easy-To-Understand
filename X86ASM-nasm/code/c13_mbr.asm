;
; MBR, Prgram loader 
;
; 按照作者的代码，将保护模式的代码段基地址设置为0x7c00，段限制设置为0x1FF，512字节
; 如果使用作者的形式，这里不能定义vstart=0x7C00，否则段访问会出错
; 如果要编译成vstart=0x7c00，那么必须将代码段的描述符修改一下，比如基地址0，段限制64K 
SECTION mbr align=16 vstart=0x7C00
[bits 16]
    jmp near start    
   
;
; clear screen
;   
cls_screen:
    push es
    push ax
    push bx
    push cx
    
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
    
    pop cx
    pop bx
    pop ax
    pop es
    ret   
            
start: 
    xor ax, ax   
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00
    
    call cls_screen
    
    ; install gdt
    mov eax, [pgdt + 2] ; + 0x7c00
    xor edx, edx
    mov ebx, 0x10
    div ebx
    mov ebx, edx
    
    push ds
    mov ds, eax
    ;descriptor 0
    mov dword [bx + 4*0], 0x0
    mov dword [bx + 4*1], 0x0
    
    ; descriptor 1 data segment
    mov dword [bx + 4*2], 0x0000FFFF
    mov dword [bx + 4*3], 0x00CF9200
    
    ; descriptor 2  code segment
    mov dword [bx + 4*4], 0x0000FFFF
    mov dword [bx + 4*5], 0x00409800
    
    ; descriptor 3  code segment 2
    mov dword [bx + 4*6], 0x0000FFFF
    mov dword [bx + 4*7], 0x00409200

    ; descriptor 4  code segment 3
    mov dword [bx + 4*8], 0x7C00FFFE
    mov dword [bx + 4*9], 0x00CF9600
    
    pop ds
    mov word [pgdt], 39 ; + 0x7c00
    
    lgdt [pgdt]  ; + 0x7c00
    
    in al, 0x92     ; A20 Address Line
    or al, 0x02
    out 0x92, al
    
    cli      
    
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    
    jmp dword 0x0010:flush
    
    [bits 32]
flush:
    mov eax, 0x0018 ; data 0x10
    mov ds, eax
    
    mov eax, 0x0008
    mov es, eax
    mov fs, eax
    mov gs, eax
    
    mov eax, 0x0020    ; index 4
    mov ss, eax
    xor esp, esp    
    
    mov byte [ES:0xB8000], 'P'
    mov byte [ES:0xB8002], 'r'
    mov byte [ES:0xB8004], 'o'
    mov byte [ES:0xB8006], 't'
    mov byte [ES:0xB8008], 'e'
    mov byte [ES:0xB800a], 'c'
    mov byte [ES:0xB800c], 't'
    mov byte [ES:0xB800e], ' '
    mov byte [ES:0xB8010], 'm'
    mov byte [ES:0xB8012], 'o'
    mov byte [ES:0xB8014], 'd'                                        
    mov byte [ES:0xB8016], 'e'
    mov byte [ES:0xB8018], ' '
    mov byte [ES:0xB801a], 'O'
    mov byte [ES:0xB801c], 'K'
    mov byte [ES:0xB801e], '!'
    
    ; buble order
    mov ecx, pgdt-string-1
 @@1:
    push ecx
    xor bx, bx
 @@2:
    mov ax, [string+bx]
    cmp ah, al
    jge @@3
    xchg al, ah
    mov [string+bx], ax
 @@3:
    inc bx
    loop @@2
    pop ecx
    loop @@1
    
    ; output string
    mov cx, pgdt-string
    xor ebx, ebx
 @@4:
    mov ah, 0x07
    mov al, [string+ebx]
    mov [es:0xb80a0 + ebx * 2], ax
    inc ebx
    loop @@4
     
    hlt        

    string    db  's0ke4or92xap3fv8giuzjcy5l1m7hd6bnqtw.' 

    pgdt      dw  63
              dd  0x00007e00
    
    times 510 - ($-$$) db 0
    db 0x55, 0xaa