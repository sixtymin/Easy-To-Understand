;
; MBR, Prgram loader 
;
; 按照作者的代码，将保护模式的代码段基地址设置为0x7c00，段限制设置为0x1FF，512字节
; 如果使用作者的形式，这里不能定义vstart=0x7C00，否则段访问会出错
; 如果要编译成vstart=0x7c00，那么必须将代码段的描述符修改一下，比如基地址0，段限制64K

core_code_lba     equ   0x00000001
core_load_addr    equ   0x00040000
 
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
    
    ; descriptor 1 code segment   0000_0000 0000_1000   0x0008
    mov dword [bx + 4*2], 0x0000FFFF
    mov dword [bx + 4*3], 0x00CF9800
    
    ; descriptor 2  code segment  0000_0000 0001_0000   0x0010
    mov dword [bx + 4*4], 0x0000FFFF
    mov dword [bx + 4*5], 0x00CF9200
    
    pop ds
    mov word [pgdt], 23 ; + 0x7c00    
    lgdt [pgdt]  ; + 0x7c00
    
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
    mov eax, 0x0010
    mov ds, eax
    mov fs, eax
    mov gs, eax
    mov es, eax    
    mov ss, eax
    mov esp, 0x7000
        
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
    
    ; 创建系统内核的也目录表PDT
    mov ebx, 0x00020000
    
    ; 在页目录内创建指向页目录表自己的目录项
    mov dword [ebx+4092], 0x00020003
    
    mov edx, 0x00021003
    ; 在页目录内创建于线性地址0x00000000对应的目录项
    mov [ebx + 0x000], edx
    ; 创建于线性地址0x80000000对应的目录项 
    mov [ebx + 0x800], edx
    
    ; 创建于上面目录项对应的页表
    mov ebx, 0x21000 
    xor eax, eax
    xor esi, esi
 .b1:
    mov edx, eax
    or edx, 0x00000003
    mov [ebx + esi*4], edx
    add eax, 0x1000
    inc esi
    cmp esi, 256
    jl .b1
    
    ; CR3寄存器指向页目录，并开启页功能
    mov eax, 0x00020000  ; PCD=PWT=0
    mov cr3, eax 
    
    ; GDT线性地址映射到从0x80000000开始的相同位置
    sgdt [pgdt]
    mov ebx, [pgdt + 2]
    add dword [pgdt + 2], 0x80000000
    lgdt [pgdt]
    
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    
    ; 将堆栈映射到高端地址
    ; 将内核的所有程序都映射到高端
    add esp, 0x80000000
    
    jmp [0x80040004]
     
    hlt       
 
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

    pgdt      dw  23
              dd  0x00008000
    
    times 510 - ($-$$) db 0
    db 0x55, 0xaa