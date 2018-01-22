;
; MBR, Prgram loader 
;
; 按照作者的代码，将保护模式的代码段基地址设置为0x7c00，段限制设置为0x1FF，512字节
; 如果使用作者的形式，这里不能定义vstart=0x7C00，否则段访问会出错
; 如果要编译成vstart=0x7c00，那么必须将代码段的描述符修改一下，比如基地址0，段限制64K

core_code_lba     equ   1

 
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
       
;
; make gdt descriptor
; Param:
;    EDX  Base
;    EAX    
;    ECX  limit    
make_gdt_descriptor:
    push edx
    push ecx
    push ebx
    push eax

    mov ebx, edx
    and ebx, 0x0000FFFF
    shl ebx, 16
    or bx, ax
    
    sgdt [pgdt]
    mov esi, dword [pgdt+2]
    xor edi, edi
    mov di, word [pgdt]
    shl di, 3
    inc di
    mov dword [esi + edi * 8], ebx
    
    mov ebx, edx
    and ebx, 0xFFFF0000
    rol ebx, 8
    bswap ebx
    and eax, 0x000F0000
    shr eax, 8
    or ax, cx
    shl ecx, 8
    and ecx, 0x00FFFF00
    or ebx, ecx
    mov dword [esi + edi * 8 + 4], ebx 
        
    pop eax
    pop ebx
    pop ecx
    pop edx
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
    
    ; descriptor 1 data segment   0000_0000 0000_1000
    mov dword [bx + 4*2], 0x0000FFFF
    mov dword [bx + 4*3], 0x00CF9200
    
    ; descriptor 2  code segment  0000_0000 0001_0000
    mov dword [bx + 4*4], 0x0000FFFF
    mov dword [bx + 4*5], 0x00409800

    ; descriptor 3  stack segment 0000_0000 0001_1000
    mov dword [bx + 4*6], 0x7C00FFFC
    mov dword [bx + 4*7], 0x00CF9600

    ; descriptor 4  vide segment  0000_0000 0010_0000
    mov dword [bx + 4*8], 0x80007FFF
    mov dword [bx + 4*9], 0x00C0920B    
    
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
    mov eax, 0x0008
    mov ds, eax
    mov fs, eax
    mov gs, eax
    
    mov eax, 0x0020
    mov es, eax
        
    mov eax, 0x0018    ; index 3
    mov ss, eax
    xor esp, esp
    
    ; load core
           

     
    hlt        

    pgdt      dw  63
              dd  0x00007e00
    
    times 510 - ($-$$) db 0
    db 0x55, 0xaa