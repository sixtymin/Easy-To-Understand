;
; MBR, Prgram loader 
;
; 按照作者的代码，将保护模式的代码段基地址设置为0x7c00，段限制设置为0x1FF，512字节
; 如果使用作者的形式，这里不能定义vstart=0x7C00，否则段访问会出错
; 如果要编译成vstart=0x7c00，那么必须将代码段的描述符修改一下，比如基地址0，段限制64K

core_code_lba     equ   0x00000001
core_load_addr    equ   0x00040000
core_code_seg_sel equ   0x0038
 
SECTION mbr align=16 vstart=0x7C00

[bits 16]
    jmp near start    
                
start: 
    xor ax, ax   
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00
    
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
    
    ; descriptor 1 data segment   0000_0000 0000_1000   0x0008
    mov dword [bx + 4*2], 0x0000FFFF
    mov dword [bx + 4*3], 0x00CF9200
    
    ; descriptor 2  code segment  0000_0000 0001_0000   0x0010
    mov dword [bx + 4*4], 0x0000FFFF
    mov dword [bx + 4*5], 0x00409800

    ; descriptor 3  stack segment 0000_0000 0001_1000   0x0018
    mov dword [bx + 4*6], 0x7C00FFFC
    mov dword [bx + 4*7], 0x00CF9600

    ; descriptor 4  vide segment  0000_0000 0010_0000   0x0020
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
    mov eax, core_code_lba
    mov edi, core_load_addr
    call read_hard_disk_section
    
    mov eax, [core_load_addr]
    xor edx, edx
    mov ebx, 512
    div ebx
    or edx, edx
    jnz readmore
    dec eax
  
 readmore:
    or eax, eax
    jz setgdt
    
    mov ecx, eax
    mov eax, core_code_lba    
  readsec:        
    inc eax
    add edi, 512  
    call read_hard_disk_section  
    loop readsec
    
 setgdt:    
    mov edi, core_load_addr    
    mov eax, [core_load_addr + 0x4]
    lea edx, [edi + eax]
    mov eax, 0x00409800
    mov ecx, 0xFFFFF     
    call make_gdt_descriptor            ; 0x28

    mov esi, dword [pgdt+2]
    xor ebx, ebx
    mov bx,  word [pgdt]
    add esi, ebx
    inc esi
    mov dword [esi], eax
    add esi, 0x4
    mov dword [esi], edx    
     
    mov eax, [core_load_addr + 0x8]
    lea edx, [edi + eax]
    mov eax, 0x00409200
    mov ecx, 0xFFFFF
    call make_gdt_descriptor            ; 0x30

    add esi, 0x4    
    mov dword [esi], eax
    add esi, 0x4
    mov dword [esi], edx    
           
    mov eax, [core_load_addr + 0xC]
    lea edx, [edi + eax]
    mov eax, 0x00409800
    mov ecx, 0xFFFFF
    call make_gdt_descriptor            ; 0x38

    add esi, 0x4
    mov dword [esi], eax
    add esi, 0x4
    mov dword [esi], edx
    
    mov word [pgdt], 63
    lgdt [pgdt]

    jmp far [edi + 0x10]
     
    hlt       
    
;
; make gdt descriptor
; Param:
;    EDX  Base
;    EAX  attribute
;    ECX  limit
make_gdt_descriptor:
    push ebx

    mov ebx, edx
    shl ebx, 16
    or bx, cx      ; low 32bits
        
    and edx, 0xFFFF0000
    rol edx, 8
    bswap edx
    and ecx, 0x000F0000
    or eax, ecx
    or edx, eax    ; high 32bits
    
    mov eax, ebx

    pop ebx
    ret

;----------------------------------------------------------------------
; Functions
;
; read a section from disk
; EAX: section no.  EDI: memory buffer
read_hard_disk_section:
    push eax
    push ecx
    push edx
    push edi

    push eax
    ;mov ebx, eax
    ;mov ecx, eax

    mov dx, 0x1F2      ; 接口保存 读取几个扇区
    mov al, 0x01
    out dx, al

    ; Start Section No
    inc dx  ; mov dx, 0x1F3      ; 0x1F3/0x1F4/0x1F5/0x1F6保存起始扇区号
    ;mov al, cl
    pop eax
    out dx, al

    inc dx             ; 0x1F4
    mov cl, 8
    shr eax, cl
    out dx, al

    inc dx             ; 0x1F5
    shr eax, cl
    ;mov al, cl
    out dx, al

    inc dx             ; 0x1F6
    ;mov al, ch
    shr eax, cl
    ;and al, 0x0F
    or al, 0xE0        ; 0x1F6端口 高四字节 1X1Y  X表示CHS(0)/LBA Y表示主(0)/副磁盘
    out dx, al         ; 1110 - 0xE0 主磁盘 LBA方式读取

    ; Read Command
    ;mov dx, 0x1F7
    inc dx
    mov al, 0x20       ; 0x1F7 port 0x20 read disk
    out dx, al

    ; Test Ready
    ;mov dx, 0x1F7
 .waits:
    in al, dx
    and al, 0x88
    cmp al, 0x08
    jnz .waits

    ; Read data
    mov dx, 0x1F0     ; 0x1F0 读端口，0x1F1 为错误寄存器，包含磁盘最后一次操作状态码
    mov ecx, 256
 .readw:
    in ax, dx
    mov word [edi], ax
    add edi, 2
    loop .readw

    pop edi
    pop edx
    pop ecx
    pop eax
    ret     

    pgdt      dw  63
              dd  0x00007e00
    
    times 510 - ($-$$) db 0
    db 0x55, 0xaa