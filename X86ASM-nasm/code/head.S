; head.S
; 包含32位保护模式初始化设置代码，时钟中断代码
; 系统调用中断代码和两个人物代码
; 初始化完之后，则回退到Ring3 任务0，然后任务0和1切换执行

LATCH = 11930    ; 定时器初始计数值，每隔10ms触发一次
SCRN_SEL = 0x18
TSS0_SEL = 0x20
LDT0_SEL = 0x28
TSS1_SEL = 0x30
LDT1_SEL = 0x38

.text
startup_32:
    movl $0x10, %eax
    mov %ax, %ds
    lss init_stack, %esp  ; 将init_stack地址处的 DWORD和WORD赋值给 esp/ss
    
    call setup_idt
    call setup_gdt
    movl $0x10, %eax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    lss init_stack, %esp
    
    ; 设置8253定时器
    movb $0x36, %al
    movl $0x43, %edx  ; 8253芯片控制字寄存器的写端口
    outb %al, %dx
    movl $LATCH, %eax
    movl $0x40, %edx
    outb %al, %dx
    movb %ah, %al
    outb %al, %dx     ; 分两次将计数 值写入通道0
    
    ; IDT表的第8和第128项 分别设置为定时中断描述符和系统调用陷阱们描述符
    movl $0x00080000, %eax
    movw $time_interrupt, %ax
    movw $0x8e00, %dx
    movl $0x80, %ecx
    lea idt(, %ecx, 8), %esi
    movl %eax, (%esi)
    movl %edx, 4(%esi)      ; 第8项设置
    
    movw $system_interrupt, %ax
    movw $0xef00, %dx
    movl $0x80, %ecx        ; 系统调用向量 0x80
    lea idt(,%ecx, 8), %esi
    movl %eax, (%esi)
    movl %edx, 4(%esi)
    
    pushfl    ; 复位EFLAGS中的嵌套任务标志
    andl $0xFFFFBFFF, (%esp)
    popfl
    
    movl $TSS0_SEL, %eax
    ltr %ax
    movl $LDT0_SEL, %eax
    lldt %ax
    
    movl $0, current      ; 当前任务号
    
    sti                   ; 设置完毕，开启中断
    pushl $0x17
    pushl $init_stack
    pushfl
    pushl $0x0f
    pushl $task0
    iret                  ; 切换到 特权级3的任务0中

; 设置GDTR寄存器    
setup_gdt:
    lgdt lgdt_opcode
    ret

; 设置IDT表，并加载IDTR寄存器 
setup_idt:
    
    lea ignore_int, %edx
    movl $0x00080000, %eax
    movw %dx, %ax
    movw $0x8e00, %dx
    lea idt, %edi
    mov $256, %ecx        ; 循环设置256个门描述符
 rp_idt:
    movl %eax, (%edi)
    movl %edx, 4(%edi)
    addl $8, %edi
    loop rp_idt
    
    lidt lidt_opcode      ; 6字节操作数加载到IDTR寄存器
    ret 
    
; 显示字符 的 子程序
; AL为要显示字符，src_loc中保存了当前光标位置
write_char:
    push %gs
    pushl %ebx
    mov $SCRN_SEL, %ebx
    mov %bx, %gs
    movl scr_loc, %bx
    shl $1, %ebx
    movb %al, %gs:(%ebx)
    shr $1, %ebx
    incl %ebx
    cmpl $2000, %ebx
    jb 1f
    movl $0, %ebx
 1: 
    mov %ebx, scr_loc
    popl %ebx
    pop %gs
    ret
    
; 三个中断处理过程：
.align 2
ignore_int:
    push %ds
    pushl %eax
    movl %0x10, %eax  ; ds指向内核数据段 
    mov %ax, %ds
    
    mov $67, %eax     ; 输出字符"C" 
    call write_char 
    
    popl %eax
    pop %ds
    iret
    
; 定时器中断处理过程
.align 2
timer_interrupt:
    push %ds
    pushl %eax
    movl $0x10, %eax
    mov %eax, %ds     ; 切换ds到内核数据段 
    
    movb %0x20, %al
    outb %al, $0x20   ; 项8259A发送EOI指令
    
    movl $1, %eax
    cmpl %eax, current
    je 1f
    movl %eax, current    ; 任务0，要切换到任务1了
    ljmp $TSS1_SEL, $0
    jmp 2f
 1: 
    movl $0, current
    ljmp $TSS0_SEL, $0    ; 任务1， 切换到任务0
 2: 
    popl %eax
    pop %ds
    iret
    
; 中断调用 int 0x80处理程序，显示字符功能，相当于系统调用
.align 2
system_interrupt:
    push %ds
    pushl %edx
    pushl %ecx
    pushl %ebx
    pushl %eax
    
    movl $0x10, %edx
    mov %dx, %ds
    call write_char
    popl %eax
    popl %ebx 
    popl %ecx
    popl %edx
    popl %ds
    iret
    

;
current: .long 0            ; 当前任务号 
scr_loc: .long 0            ; 当前显示位置

.align 2
lidt_opcode:
    .word 256*8-1
    .long idt

lgdt_opcode:
    .word (end_gdt-gdt)-1
    .long gdt
    
.align 3
idt: 
    .fill 256, 8, 0 
    
gdt:
    .quad 0x0000000000000000
    .quad 0x00c09a0000000000
    .quad 0x00c0920000000000
    .quad 0x00c0920b80000002
    .word 0x68, tss0, 0xe900, 0x0
    .word 0x40, ldt0, 0xe200, 0x0
    .word 0x68, tss1, 0xe900, 0x0
    .word 0x40, ldt1, 0xe200, 0x0
end_gdt:

    .fill 128, 4, 0
init_stack:
    .long init_stack
    .word 0x10
    
; 任务 0 
.align 3
ldt0:
    .quad 0x0000000000000000
    .quad 0x00c0fa00000003ff
    .quad 0x00c0f200000003ff
    
tss0:                            
    .long 0                      ; back link
    .long krn_stk0, 0x10         ; esp0, ss0
    .long 0, 0, 0, 0, 0          ; esp1, ss1, esp2, ss2, cr3
    .long 0, 0, 0, 0, 0          ; eip, eflags, eax, ecx, edx
    .long 0, 0, 0, 0, 0          ; ebx, esp, ebp, esi, edi
    .long 0, 0, 0, 0, 0, 0       ; es, cs, ss, ds, fs, gs
    .long LDT0_SEL, 0x8000000    ; ldt, trace bitmap
    
    .fill 128, 4, 0              ; 任务0 的内核栈空间
krn_stk0:            

; 任务 1 
.align 3
ldt1:
    .quad 0x0000000000000000
    .quad 0x00c0fa00000003ff
    .quad 0x00c0f200000003ff

tss1:
    .long 0                      ; back link
    .long krn_stk1, 0x10         ; esp0, ss0
    .long 0, 0, 0, 0, 0          ; esp1, ss1, esp2, ss2, cr3
    .long 0, 0, 0, 0, 0          ; eip, eflags, eax, ecx, edx
    .long 0, 0, 0, 0, 0          ; ebx, esp, ebp, esi, edi
    .long 0, 0, 0, 0, 0, 0       ; es, cs, ss, ds, fs, gs
    .long LDT1_SEL, 0x8000000    ; ldt, trace bitmap

    .fill 128, 4, 0              ; 任务0 的内核栈空间
krn_stk1:    
     
        
; task0 和 task1 d的代码
task0:
    movl $0x17, %eax
    movw %ax, %ds
    movl $65, %al
    int $0x80
    movl $0xFFF, %ecx
 1: 
    loop 1b
    jmp task0

task1:
    movl $0x17, %eax
    movw %ax, %ds
    movl $66, %al
    int $0x80
    movl $0xFFF, %ecx
 1:
    loop 1b
    jmp task1
    
    .fill 128, 4, 0
usr_stk1:         
    
 
     
    