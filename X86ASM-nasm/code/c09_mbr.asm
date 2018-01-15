;
; MBR, Prgram loader 
;
    app_lba_start equ 10
    

SECTION mbr align=16 vstart=0x7C00

    jmp near start    

    phy_base      dd  0x10000
        
start: 
    xor ax, ax
    mov ds, ax    
    mov ss, ax
    mov sp, 0x7C00

    mov ax, [phy_base]
    shr ax, 4
    mov bx, [phy_base + 2]
    shl bx, 12
    or ax, bx
    mov es, ax
    xor di, di
    mov cx, app_lba_start
    call read_harddisk_0
    
    xor di, di
    mov ax, [es:di]
    mov dx, [es:di+2]
    mov bx, 512
    div bx
    cmp dx, 0
    jnz b1
    dec ax
  b1:
    cmp ax, 0
    jz direct
    mov cx, ax
    push es
    mov bx, (app_lba_start + 1)
readsecs:        
    push cx
    mov cx, bx   ; start section no
    xor di, di   ; ES:DI address
    mov ax, es
    add ax, 0x20
    mov es, ax
    call read_harddisk_0
    pop cx
    inc bx       ; 下一个扇区 
    loop readsecs    
    pop es       ; 重定位
        
 direct:        
    mov di, 0x6
    mov ax, [es:di]
    mov dx, [es:di + 0x2]
    call calc_segment_base
    mov [es:di], ax
    
    mov cx, [es:di + 0x4]   ; 表项数
    mov di, 12
reloc:
    mov ax, [es:di]
    mov dx, [es:di + 0x2]
    call calc_segment_base
    mov [es:di], ax
    add di, 4    
    loop reloc 
    
    mov ax, es
    mov ds, ax 
    jmp far [0x4]
    
    ; param:
    ;   DX:AX  Base Address
    ; ret:
    ;   AX  - segment value  
calc_segment_base:    
    add ax, [phy_base]         ; 加上基地址 
    adc dx, [phy_base + 2]     ; 32位加法，高16字节加法用adc，带上进位 
    
    shr ax, 4
    and ax, 0x0FFF  ; 右移是可能出现EAX 高16位不为0 的情况 
    shl dx, 12
    or ax, dx        
    ret
    ; 
    ; Read Main HardDisk
    ; CX     start section no.
    ; ES:DI  buffer address
    ;    
read_harddisk_0:
    ; Read Section Number
    push dx
    
    mov dx, 0x1F2      ; 接口保存 读取几个扇区 
    mov al, 0x01
    out dx, al
    
    ; Start Section No
    mov dx, 0x1F3      ; 0x1F3/0x1F4/0x1F5/0x1F6保存起始扇区号 
    mov al, cl
    out dx, al    
    inc dx             ; 0x1F4
    mov al, ch
    out dx, al
    inc dx             ; 0x1F5
    xor ax, ax 
    out dx, al
    inc dx             ; 0x1F6
    mov al, 0xE0       ; 0x1F6端口 高四字节 1X1Y  X表示CHS(0)/LBA Y表示主(0)/副磁盘 
    out dx, al         ; 1110 - 0xE0 主磁盘 LBA方式读取 
       
    ; Read Command
    mov dx, 0x1F7
    mov al, 0x20       ; 0x1F7 port 0x20 read disk    
    out dx, al
 
    ; Test Ready   
    mov dx, 0x1F7
 .waits:
    in al, dx
    and al, 0x88
    cmp al, 0x08
    jnz .waits
    
    ; Read data
    mov dx, 0x1F0     ; 0x1F0 读端口，0x1F1 为错误寄存器，包含磁盘最后一次操作状态码
    mov cx, 256
 .readw:
    in ax, dx
    mov [ES:DI], ax
    add di, 2
    loop .readw
    
    pop dx
    
    ret        
    
    times 510 - ($-$$) db 0
    db 0x55, 0xaa