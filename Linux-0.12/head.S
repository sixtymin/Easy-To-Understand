# head.S
# 包含32位保护模式初始化设置代码，时钟中断代码
# 系统调用中断代码和两个人物代码
# 初始化完之后，则回退到Ring3 任务0，然后任务0和1切换执行

LATCH = 11930    # 定时器初始计数值，每隔10ms触发一次
SCRN_SEL = 0x18
TSS0_SEL = 0x20
LDT0_SEL = 0x28
TSS1_SEL = 0x30
LDT1_SEL = 0x38

.text
startup_32:
    movl $0x10, %eax
    mov %ax, %ds
    lss init_stack, %esp  # 将init_stack地址处的 DWORD和WORD赋值给 esp/ss
    
    call setup_idt
    call setup_gdt
    movl $0x10, %eax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    lss init_stack, %esp
    
    # 设置8253定时器
    movb $0x36, %al
    movl $0x43, %edx  # 8253芯片控制字寄存器的写端口
    outb %al, %dx
    movl $LATCH, %eax
    movl $0x40, %edx
    outb %al, %dx
    movb %ah, %al
    outb %al, %dx     # 分两次将计数 值写入通道0
    
    # IDT表的第8和第128项 分别设置为定时中断描述符和系统调用陷阱们描述符
    movl $0x00080000, %eax
    movw $time_interrupt, %ax
    movw $0x8e00, %dx
    movl $0x80, %ecx
    lea idt(, %ecx, 8), %esi
    movl %eax, (%esi)
    movl %edx, 4(%esi)
     
     
 

 
