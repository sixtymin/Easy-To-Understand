; boot.s
; 将head的代码利用BIOS加载到0x10000处，然后移动到
; 内存0处，进入保护模式，并跳转到内存0处继续执行

BOOTSEG = 0x07c0
SYSSEG = 0x1000
SYSLEN = 17
entry start

start:
    jmpi  go, #BOOTSEG
 go:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov sp, #0x400   ; 从0x7c00 + 0x400作为栈顶
    
 load_system:
    mov dx, #0x0000  ; DH - 磁头号 DL - 驱动器号 CH-10位磁道号低8位 
    mov cx, #0x0002  ; CL - 高两位与CH组成磁道号，低5位为起始扇区号 
    mov ax, #SYSSEG
    mov es, ax       ; ES:BX - 读入缓冲区位置 
    xor bx, bx       ; AH - 读磁盘的功能号 AL - 需要读取扇区数 
    mov ax, #0x200+SYSLEN
    int 0x13
    jnc ok_load    
 die: 
    jmp die
    
 ok_load:
    cli
    mov ax, #SYSSEG
    mov ds, ax
    xor ax, ax
    mov es, ax
    mov cx, #0x1000
    sub si, si
    sub di, di
    rep movw       ; 重复执行指令
    
    ; 加载GDT/IDT
    mov ax, #BOOTSEG
    mov ds, ax
    lidt idt_48
    lgdt gdt_48
    
    mov ax, #0x0001
    lmsw ax        ; 设置机器状态字指令，即设置CR0 
    jmpi 0, 8      ; 跳转到 head执行 
    
gdt: 
    .word 0,0,0,0    ; 描述符0

    .word 0x07FF
    .word 0x0000
    .word 0x9A00     ; 代码段 可读/执行 
    .word 0x00C0
      
    .word 0x07FF
    .word 0x0000
    .word 0x9200     ; 数据段，可读写 
    .word 0x00C0

idt_48: 
    .word 0
    .word 0, 0
         
gdt_48: 
    .word 0x7FF
    .word 0x7c00+gdt, 0
    
.org 510
    .word 0xAA55    
         