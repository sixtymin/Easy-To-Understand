;
; Core
;

app_prog_lba       equ     20   ; 应用程序所在的起始扇区号
app_prog_startoff  equ     0x10 ; 应用程序起始偏移 

core_code_seg_sel   equ    0x38
core_data_seg_sel   equ    0x30
sys_routine_seg_sel equ    0x28
video_ram_seg_sel   equ    0x20
core_stack_seg_sel  equ    0x18
mem_0_4_gb_seg_sel  equ    0x08

    core_length     dd  core_end
    sys_funcs_off   dd  section.sys_routine.start    
    coredata_off    dd  section.core_data.start
    corecode_off    dd  section.core_code.start
    entry_off       dd  start    
    enty_seg        dw  core_code_seg_sel

[bits 32]      
SECTION sys_routine align=16 vstart=0

;
; BX 保存坐标值
;
far_set_cursor_pos:
    push edx
    push eax
    mov dx, 0x3d4   ; 重置光标位置
    mov al, 0x0e
    out dx, al
    mov dx, 0x3d5
    mov al, bh
    out dx, al
    mov dx, 0x3d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x3d5
    mov al, bl
    out dx, al
    pop eax
    pop edx
    retf

;
; BX 保存坐标值 
; 
set_cursor_pos:
    push edx
    push eax
    mov dx, 0x3d4   ; 重置光标位置
    mov al, 0x0e
    out dx, al
    mov dx, 0x3d5    
    mov al, bh
    out dx, al
    mov dx, 0x3d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x3d5
    mov al, bl
    out dx, al
    pop eax
    pop edx
    ret
;
; ax return pos info
;
get_cursor_pos:
    push edx
    mov dx, 0x3d4   ; 读取光标位置
    mov al, 0x0e
    out dx, al
    mov dx, 0x3d5
    in al, dx
    mov ah, al
    mov dx, 0x3d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x3d5
    in al, dx
    pop edx
    ret

;
; Show a char on screen
; cl : output char value
put_char:
    push es
    push ds 
    push esi
    push edi
    push edx
    push ebx
    push eax
    
    mov eax, video_ram_seg_sel
    mov es, eax
    mov ds, eax
    
    xor eax, eax    
    call get_cursor_pos
    mov ebx, eax
    
    cmp cl, 0x0d
    jz put_0d
    cmp cl, 0x0a
    jz put_0a
    
    shl ebx, 1  ; 输出正常字符
    mov [es:ebx], cl
    shr ebx, 1
    inc ebx
    jmp crll_screen  ; 是否卷屏 
     
  put_0d:    
    mov ax, bx
    mov bl, 80
    div bl
    mul bl
    mov bx, ax   
    jmp reset_cur  
  put_0a:
    add ebx, 80
  crll_screen:
    cmp ebx, 2000
    jb reset_cur

    xor edi, edi  ; 卷屏
    mov esi, 0xa0
    mov ecx, 1920
    rep movsw

    mov eax, 0x20
    mov ecx, 80
  cls_ln:
    mov byte [edi], al
    add edi, 2
    loop cls_ln

    mov ebx, 1920   ; 设置光标位置

  reset_cur: 
    call set_cursor_pos

    pop eax
    pop ebx    
    pop edx
    pop edi
    pop esi
    pop ds
    pop es
    ret      
;
; Show a string(zero end) on screen
; param:
;   DS:EBX  指向要输出字符串（0结束符）基地址 
put_string:
    push ecx
    push eax
    xor eax, eax
  more:
    mov al, [ebx]
    cmp al, 0
    jz str_end
    mov cl, al
    call put_char
    inc ebx    
    jmp more    
 str_end:
    pop eax
    pop ecx
    retf    
;
; clean screen 
;
screen_cls:
    push es
    push ecx
    push edi
    push eax
    
    xor edi, edi    
    mov eax, video_ram_seg_sel
    mov es, eax
    mov ecx, 2000
    mov eax, 0x0720
mov_word:    
    mov [es:edi], ax
    add edi, 2
    loop mov_word 
    
    pop eax
    pop edi
    pop ecx
    pop es
    retf 

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
    retf

; 
; For debug, output DWORD
;
put_hex_dword:
    
    pushad
    push ds
    
    mov ax, core_data_seg_sel
    mov ds, ax
    
    mov ebx, bin_hex
    mov ecx, 8
 .xlt:
    rol edx, 4
    mov eax, edx
    and eax, 0x0000000F
    xlat
    
    push ecx
    mov cl, al
    call put_char
    pop ecx
    
    loop .xlt
    
    pop ds
    popad
    retf

;
; ECX - [Input] Size to Alloc
; ECX - [Output] Alloc Base Address
allocate_memory:
    push ds
    push eax
    push ebx
    
    mov eax, core_data_seg_sel
    mov ds, eax
    mov eax, [ram_alloc]
    add eax, ecx
    
    mov ecx, [ram_alloc]
    mov ebx, eax
    and ebx, 0xFFFFFFFC
    add ebx, 4
    test eax, 0x00000003
    cmovnz eax, ebx
    mov [ram_alloc], eax
    
    pop ebx
    pop eax
    pop ds
    
    retf

; EDX:EAX - [IN]  descriptor item
; CX - [OUT] selector
;
set_up_gdt_descriptor:
    push eax
    push ebx 
    push edx
    
    push ds
    push es
    
    mov ebx, core_data_seg_sel
    mov ds, ebx
    
    sgdt [pgdt]
    mov ebx, mem_0_4_gb_seg_sel
    mov es, ebx
    
    movzx ebx, word [pgdt]
    inc bx
    add ebx, [pgdt + 2]
    
    mov [es:ebx], eax
    mov [es:ebx+4], edx
    
    add word [pgdt], 8
    
    lgdt [pgdt]
    
    mov ax, [pgdt]   ; calc selector
    xor dx, dx
    mov bx, 8
    div bx
    mov cx, ax
    shl cx, 3
            
    pop es
    pop ds
    pop edx
    pop ebx
    pop eax
    retf

; EAX - [IN] line base address
; EBX - [IN] limit
; ECX - [IN] attributes
;
; EDX:EAX - [OUT] descriptor
;
make_seg_descriptor:
    mov edx, eax
    shl eax, 16
    or ax, bx
    
    and edx, 0xFFFF0000
    rol edx, 8
    bswap edx
    
    xor bx, bx
    or edx, ebx
    and ecx, 0xFFF0FFFF   ; 保证段界限的4位为0 
    or edx, ecx
    
    retf

; EAX - [IN] line base address
; EBX - [IN] selector
; ECX - [IN] attributes
;
; EDX:EAX - [OUT] descriptor
;
make_gate_descriptor:
    push ebx
    push ecx
    
    mov edx, eax
    and eax, 0x0000FFFF
    shl ebx, 16
    and ebx, 0xFFFF0000
    or eax, ebx

    and edx, 0xFFFF0000
    and ecx, 0x0000FFFF   
    or edx, ecx
    
    pop ecx
    pop ecx
    retf

terminate_current_task:
    
    mov eax, core_data_seg_sel
    mov ds, eax
    
    pushfd
    pop edx
        
    test dx, 0100_0000_0000_0000B
    jnz .b1
    jmp far [prgman_tss]
    
  .b1:
    iretd    

;
; 分配一个4K的页 
; EAX=页的物理地址 
allocate_a_4k_page:
   
   push ebx
   push ecx
   push edx
   push ds
   
   mov eax, core_data_seg_sel
   mov ds, eax
   
   xor eax, eax
 .b1:
   bts [page_bit_map], eax
   jnc .b2
   inc eax
   cmp eax, page_map_len*8
   jl .b1
   
   mov ebx, message_3
   call sys_routine_seg_sel:put_string
   hlt
   
 .b2:
   shl eax, 12
   
   pop ds
   pop edx
   pop ecx
   pop ebx
   
   ret
         
;
; 分配一个页，并安装在当前活动的层级分页结构中
; EBX=页的线性地址 
;    
alloc_inst_a_page:
    
    push eax
    push ebx 
    push esi
    push ds
    
    mov eax, mem_0_4_gb_seg_sel
    mov ds, eax
    
    mov esi, ebx
    and esi, 0xFFC00000
    shr esi, 20    ; 页目录索引，乘以4 shr esi 22， shl esi 2
    or esi, 0xFFFFF000
    
    test dword [esi], 0x00000001     ; 判断P位是否为1，即页表是否存在 
    jnz .b1
    
    ; 创建线性地址对应页表
    call allocate_a_4k_page          ; 分配一个页表 
    or eax, 0x00000007
    mov [esi], eax                   ; 存储到页目录中对应条目 
 .b1:
    ; 访问线性地址对应页表   
    ; 这里有一个技巧： 
    ; 页目录的最后一个条目保存了页目录的页表项
    ; 所以 要访问页目录中的某一个条目 最高10位要设置为0xFFC 
    ; 中间10位为 页目录的索引（即线性地址的最高10位） 
    ; 再将 线性地址的中间10位 乘以4 设置到低12位上
    ; 这样才能访问页表中的 某一项 
    mov esi, ebx
    shr esi, 10 
    and esi, 0x003FF000
    or esi, 0xFFC00000     ; 页表线性地址
    
    and ebx, 0x003FF000
    shr ebx, 10 
    or esi, ebx      ; 页表项的线性地址
    call allocate_a_4k_page ; 分配一个页，要安装的页
    or eax, 0x00000007
    mov [esi], eax 
            
    pop ds
    pop esi
    pop ebx
    pop eax
    
    retf       
    
SECTION core_data align=16 vstart=0
    pgdt      dw   0
              dd   0
              
    page_bit_map db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x55, 0x55, 0xFF
                 db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
                 db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
                 db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
                 db 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55
                 db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                 db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                 db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                 db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00                                                   
                 
    page_map_len equ $-page_bit_map
              
    ram_alloc dd   0x00100000
    
    ; 检索表
    salt:
    salt_1    db   '@PrintString'
              times 256-($-salt_1) db 0
              dd   put_string
              dw   sys_routine_seg_sel
    salt_2    db   '@ReadDiskData'
              times 256-($-salt_2) db 0
              dd   read_hard_disk_section
              dw   sys_routine_seg_sel
    salt_3    db   '@PrintDwordAsHexString'
              times 256-($-salt_3) db 0
              dd   put_hex_dword
              dw   sys_routine_seg_sel
    salt_4    db   '@TerminateProgram'
              times 256-($-salt_4) db 0
              dd   terminate_current_task
              dw   sys_routine_seg_sel
    
    salt_item_len equ $-salt_4
    salt_items    equ 4;($-salt)/salt_item_len

    message_0 db ' Working in system core, protect mode.'
              db 0x0d,0x0a,0
    
    message_1 db ' Paging is enabled. System core is mapped to'
              db ' address 0x80000000.',0x0d,0x0a,0
    message_2 db 0x0d,0x0a 
              db ' System wide CALL-GATE mounted.',0x0d,0x0a,0
    
    message_3 db '********No more pages********',0
    
    message_4 db 0x0d,0x0a,' Task switching...@_@',0x0d,0x0a,0
    
    message_5 db 0x0d,0x0a,' Processor HALT.',0
              
    bin_hex db '0123456789ABCDEF'
    
    core_buf times 2048 db 0
    
    cpu_brand0 db 0x0d,0x0a,' ',0
    cpu_brand times 64 db 0
    cpu_brand1 db 0x0d,0x0a,0x0d,0x0a,0    
    
    tcb_chain  dd 0   ; 任务控制块链
    
    ;程序管理器的任务信息
    prgman_tss dd 0   ; 程序管理器TSS基地址                               
               dw 0   ; 程序管理器TSS描述符选择子
    
    core_next_laddr dd 0x80100000
                  
core_data_end:
;======================================================================    
SECTION core_code align=16 vstart=0

;
; EDX:EAX = 描述符
; EBX=TCB基地址
; 
; CX=描述符的选择子 
;
fill_descriptor_in_ldt:
    
    push eax
    push edx
    push edi
    push ds
    
    mov ecx, mem_0_4_gb_seg_sel
    mov ds, ecx
    
    mov edi, [ebx+0x0c]  ; LDT基地址 
    
    xor ecx, ecx
    mov cx, [ebx+0x0a]
    inc cx
    
    mov [edi+ecx+0x00], eax
    mov [edi+ecx+0x04], edx
    
    add cx, 8
    dec cx
    
    mov [ebx+0x0a], cx
    
    mov ax, cx
    xor dx, dx
    mov cx, 8
    div cx
    
    mov cx, ax
    shl cx, 3
    or cx, 0000_0000_000_0100B
    
    pop ds
    pop edi
    pop edx
    pop eax
    
    ret
;
; load user program, and relocate
; [IN] 
;     push start-lba
;     push TCB-addr
;
load_relocate_program:
    pushad 
    push ds   
    push es
    
    mov ebp, esp       ; 为访问栈上参数准备基准值 
    
    mov eax,mem_0_4_gb_seg_sel
    mov es,eax                         ;切换DS到内核数据段
    
    mov esi, [ebp+11*4]   ; tcb基地址
    
    ; LDT memory
    mov ecx, 160
    call sys_routine_seg_sel:allocate_memory
    mov [es:esi+0x0c], ecx  ; LDT基地址
    mov word [es:esi+0x0a], 0xffff ; 长度为0
    
    mov eax, core_data_seg_sel
    mov ds, eax
            
    ; load user program to memory
    mov eax, [ebp+12*4]  ; 用户程序起始 LBA    
    mov edi, core_buf
    call sys_routine_seg_sel:read_hard_disk_section     ; get header
    
    mov eax, dword [core_buf]
    mov ebx, eax
    and ebx, 0xFFFFFE00
    add ebx, 512
    test eax, 0x000001FF
    cmovnz eax, ebx

    mov ecx, eax
    call sys_routine_seg_sel:allocate_memory
    mov [es:esi+0x06], ecx 
    
    mov edi, ecx
    xor edx, edx
    mov ecx, 512
    div ecx
    mov ecx, eax    ; 所有扇区数 
    
    mov eax, mem_0_4_gb_seg_sel
    mov ds, eax
    
    push edi
    mov eax, [ebp+12*4]    ; 其实扇区号 LBA 
 .b1:
    call sys_routine_seg_sel:read_hard_disk_section
    inc eax
    add edi, 512
    loop .b1
    
    ;建立程序头段描述符     0x07 
    pop edi
    mov eax, edi
    mov ebx, [edi+0x4]     ; seg len
    dec ebx
    mov ecx, 0x0040F200    ; attributes
    call sys_routine_seg_sel:make_seg_descriptor
    
    ; 安装到LDT中
    mov ebx, esi
    call fill_descriptor_in_ldt
    
    or cx, 0x03    ; 权限值设为 3 
    mov [es:esi + 0x44], cx
    mov [edi + 0x04], cx 
        
    ;建立程序代码段描述符   0x0F 
    mov eax,edi
    add eax,[edi+0x14]                 ;代码起始线性地址
    mov ebx,[edi+0x18]                 ;段长度
    dec ebx                            ;段界限
    mov ecx,0x0040F800                 ;字节粒度的代码段描述符
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    or cx, 0x03     
    mov [edi+0x14],cx

    ;建立程序数据段描述符   0x17
    mov eax,edi
    add eax,[edi+0x1c]                 ;数据段起始线性地址
    mov ebx,[edi+0x20]                 ;段长度
    dec ebx                            ;段界限
    mov ecx,0x0040F200                 ;字节粒度的数据段描述符
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    or cx, 0x03
    mov [edi+0x1c],cx

    ;建立程序堆栈段描述符   0x1F
    mov ecx,[edi+0x0c]                 ;4KB的倍率 
    mov ebx,0x000fffff
    sub ebx,ecx                        ;得到段界限
    mov eax,4096                        
    mul dword [edi+0x0c]                         
    mov ecx,eax                        ;准备为堆栈分配内存 
    call sys_routine_seg_sel:allocate_memory
    add eax,ecx                        ;得到堆栈的高端物理地址 
    mov ecx,0x00c0F600                 ;4KB粒度的堆栈段描述符
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    or cx, 0x03
    mov [edi+0x08],cx

    ;重定位SALT
    mov eax, mem_0_4_gb_seg_sel
    mov es,eax                         ;es -> 用户程序头部 
    mov eax,core_data_seg_sel
    mov ds,eax
      
    cld

    mov ecx,[es:edi+0x24]              ;用户程序的SALT条目数
    add edi,0x28                       ;用户程序内的SALT位于头部内0x2c处
  .b2: 
    push ecx
    push edi
      
    mov ecx,salt_items
    mov esi,salt
  .b3:
    push edi
    push esi
    push ecx

    mov ecx,64                         ;检索表中，每条目的比较次数 
    repe cmpsd                         ;每次比较4字节 
    jnz .b4
    mov eax,[esi]                      ;若匹配，esi恰好指向其后的地址数据
    mov [es:edi-256],eax               ;将字符串改写成偏移地址 
    mov ax,[esi+4]
    mov [es:edi-252],ax                ;以及段选择子 
  .b4:
      
    pop ecx
    pop esi
    add esi,salt_item_len
    pop edi                            ;从头比较 
    loop .b3
      
    pop edi
    add edi,256
    pop ecx
    loop .b2

    mov esi,[ebp+11*4]                 ; TCB 基地址
    
    ; 0 stack
    mov ecx, 4096
    mov eax, ecx
    mov [es:esi+0x1a], ecx
    shr dword [es:esi+0x1a], 12
    call sys_routine_seg_sel:allocate_memory
    add eax, ecx
    mov [es:esi+0x1e], eax
    mov ebx, 0xFFFFE
    mov ecx, 0x00c09600                ; 4K粒度，读写，特权级0
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    mov [es:esi+0x22], cx
    mov dword [es:esi+0x24], 0
    
    ;创建1特权级堆栈
    mov ecx,4096
    mov eax,ecx                        ;为生成堆栈高端地址做准备
    mov [es:esi+0x28],ecx
    shr dword [es:esi+0x28],12               ;登记1特权级堆栈尺寸到TCB
    call sys_routine_seg_sel:allocate_memory
    add eax,ecx                        ;堆栈必须使用高端地址为基地址
    mov [es:esi+0x2c],eax              ;登记1特权级堆栈基地址到TCB
    mov ebx,0xffffe                    ;段长度（界限）
    mov ecx,0x00c0b600                 ;4KB粒度，读写，特权级1
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx,esi                        ;TCB的基地址
    call fill_descriptor_in_ldt
    or cx,0000_0000_0000_0001          ;设置选择子的特权级为1
    mov [es:esi+0x30],cx               ;登记1特权级堆栈选择子到TCB
    mov dword [es:esi+0x32],0          ;登记1特权级堆栈初始ESP到TCB

    ;创建2特权级堆栈
    mov ecx,4096
    mov eax,ecx                        ;为生成堆栈高端地址做准备
    mov [es:esi+0x36],ecx
    shr dword [es:esi+0x36],12               ;登记2特权级堆栈尺寸到TCB
    call sys_routine_seg_sel:allocate_memory
    add eax,ecx                        ;堆栈必须使用高端地址为基地址
    mov [es:esi+0x3a],ecx              ;登记2特权级堆栈基地址到TCB
    mov ebx,0xffffe                    ;段长度（界限）
    mov ecx,0x00c0d600                 ;4KB粒度，读写，特权级2
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx,esi                        ;TCB的基地址
    call fill_descriptor_in_ldt
    or cx,0000_0000_0000_0010          ;设置选择子的特权级为2
    mov [es:esi+0x3e],cx               ;登记2特权级堆栈选择子到TCB
    mov dword [es:esi+0x40],0          ;登记2特权级堆栈初始ESP到TCB     

    ;在GDT中登记LDT描述符
    mov eax,[es:esi+0x0c]              ;LDT的起始线性地址
    movzx ebx,word [es:esi+0x0a]       ;LDT段界限
    mov ecx,0x00408200                 ;LDT描述符，特权级0
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [es:esi+0x10],cx               ;登记LDT选择子到TCB中
       
    ;创建用户程序的TSS
    mov ecx,104                        ;tss的基本尺寸
    mov [es:esi+0x12],cx              
    dec word [es:esi+0x12]             ;登记TSS界限值到TCB 
    call sys_routine_seg_sel:allocate_memory
    mov [es:esi+0x14],ecx              ;登记TSS基地址到TCB
      
    ;登记基本的TSS表格内容
    mov word [es:ecx+0],0              ;反向链=0
      
    mov edx,[es:esi+0x24]              ;登记0特权级堆栈初始ESP
    mov [es:ecx+4],edx                 ;到TSS中
      
    mov dx,[es:esi+0x22]               ;登记0特权级堆栈段选择子
    mov [es:ecx+8],dx                  ;到TSS中
      
    mov edx,[es:esi+0x32]              ;登记1特权级堆栈初始ESP
    mov [es:ecx+12],edx                ;到TSS中

    mov dx,[es:esi+0x30]               ;登记1特权级堆栈段选择子
    mov [es:ecx+16],dx                 ;到TSS中

    mov edx,[es:esi+0x40]              ;登记2特权级堆栈初始ESP
    mov [es:ecx+20],edx                ;到TSS中

    mov dx,[es:esi+0x3e]               ;登记2特权级堆栈段选择子
    mov [es:ecx+24],dx                 ;到TSS中

    mov dx,[es:esi+0x10]               ;登记任务的LDT选择子
    mov [es:ecx+96],dx                 ;到TSS中
      
    mov dx,[es:esi+0x12]               ;登记任务的I/O位图偏移
    mov [es:ecx+102],dx                ;到TSS中 
      
    mov word [es:ecx+100],0            ;T=0
    
    mov dword [es:ecx+28], 0           ; CR3
    
    ; 应用程序头部，获取数据填充TSS
    mov ebx, [ebp+11*4]                ; TCB 基地址 
    mov edi, [es:ebx+0x06]             ; 用户程序加载基地址 
    
    mov edx, [es:edi+0x10]             ; 设置程序入口
    mov [es:ecx+32], edx               ; TSS中
    
    mov dx,[es:edi+0x14]               ;登记程序代码段（CS）选择子
    mov [es:ecx+76],dx                 ;到TSS中

    mov dx,[es:edi+0x08]               ;登记程序堆栈段（SS）选择子
    mov [es:ecx+80],dx                 ;到TSS中

    mov dx,[es:edi+0x04]               ;登记程序数据段（DS）选择子
    mov word [es:ecx+84],dx            ;到TSS中。注意，它指向程序头部段
      
    mov word [es:ecx+72],0             ;TSS中的ES=0
    mov word [es:ecx+88],0             ;TSS中的FS=0
    mov word [es:ecx+92],0             ;TSS中的GS=0

    pushfd
    pop edx         
    mov dword [es:ecx+36],edx          ;EFLAGS，复用程序管理器程序的EFLAGS    
       
    ;在GDT中登记TSS描述符
    mov eax,[es:esi+0x14]              ;TSS的起始线性地址
    movzx ebx,word [es:esi+0x12]       ;段长度（界限）
    mov ecx,0x00408900                 ;TSS描述符，特权级0
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [es:esi+0x18],cx               ;登记TSS选择子到TCB

    pop es                             ;恢复到调用此过程前的es段 
    pop ds                             ;恢复到调用此过程前的ds段
            
    popad
    ret 8
    
;
; ECX=tcb基地址 
;
append_to_tcb_link:
    push eax
    push edx
    push ds
    push es
    
    mov eax, core_data_seg_sel
    mov ds, eax
    mov eax, mem_0_4_gb_seg_sel
    mov es, eax
    
    mov dword [es:ecx+0x00], 0   ; 结构体第一项清0，表示之后没内容了
    
    mov eax, [tcb_chain]
    or eax, eax
    jz .notcb
 .searc:
    mov edx, eax
    mov eax, [es:edx + 0x00]
    or eax, eax
    jnz .searc
    
    mov [es:edx + 0x00], ecx
    jmp .retpc
 .notcb:
    mov [tcb_chain], ecx ; 空表，直接将头指针指向新分配
    
 .retpc:    
    pop es
    pop ds
    pop edx
    pop eax
    ret    
    
    ;
    ; Core Start Address
    ;
start:
    mov ecx, core_data_seg_sel
    mov ds, ecx
    
    mov ecx,mem_0_4_gb_seg_sel         ;令ES指向4GB数据段 
    mov es,ecx    

    call sys_routine_seg_sel:screen_cls  ; 清屏
    
    xor ebx, ebx 
    call sys_routine_seg_sel:far_set_cursor_pos ; 设置光标位置 
    
    mov ebx, message_0
    call sys_routine_seg_sel:put_string
    
    mov eax, 0x80000002
    cpuid
    mov [cpu_brand + 0x00], eax
    mov [cpu_brand + 0x04], ebx
    mov [cpu_brand + 0x08], ecx
    mov [cpu_brand + 0x0C], edx
    
    mov eax, 0x80000003
    cpuid
    mov [cpu_brand + 0x10], eax
    mov [cpu_brand + 0x14], ebx
    mov [cpu_brand + 0x18], ecx
    mov [cpu_brand + 0x1C], edx

    mov eax, 0x80000004
    cpuid
    mov [cpu_brand + 0x20], eax
    mov [cpu_brand + 0x24], ebx
    mov [cpu_brand + 0x28], ecx
    mov [cpu_brand + 0x2C], edx
    
    mov ebx, cpu_brand0
    call sys_routine_seg_sel:put_string
    mov ebx, cpu_brand
    call sys_routine_seg_sel:put_string    
    mov ebx, cpu_brand1
    call sys_routine_seg_sel:put_string

    ; Open Page
    ; 创建内核页目录表，并将所有内容清空 
    mov ecx, 1024
    mov ebx, 0x00020000
    xor esi, esi
 .b1: 
    mov dword [es:ebx + esi], 0x00000000
    add esi, 4
    loop .b1
    
    mov dword [es:ebx+4092], 0x00020003  ; 指向页目录表自己的条目，用于访问页目录表本身
    
    ; 在页目录内创建于现行地址 0x00000000 对应的目录项
    mov dword [es:ebx+0], 0x00021003  ; 用于映射低1M的内存
    
    mov ebx, 0x00021000   ; 第一个页表的基地址，在页目录后，用于对应低1M内存 
    xor eax, eax
    xor esi, esi
 .b2:
    mov edx, eax
    or edx, 0x00000003
    mov [es:ebx+esi*4], edx
    add eax, 0x1000
    inc esi
    cmp esi, 256
    jl .b2
    
 .b3:                    ; 第一个页表中的1M内存之后的页表项都置空 
    mov dword [es:ebx + esi * 4], 0x00000000
    inc esi
    cmp esi, 1024
    jl .b3
    
    mov eax, 0x00020000  ; CR3寄存器保存页表基地址 
    mov cr3, eax
    
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    
    ;mov ebx, 0xFFFFF000   ; 页目录自己的线性基地址
    mov ebx, 0x00020000   ; 由于低1M内存直接映射为虚拟地址的低1M，因此可以直接访问页目录 
    mov esi, 0x80000000   ; 映射的起始地址
    shr esi, 22
    shl esi, 2            ; 起始地址在 在页目录中的索引（高10位 乘 4）
    mov dword [es:ebx + esi], 0x00021003  ; 将低1M内存映射到0x80000000起始地址处
    
    sgdt [pgdt]
    mov ebx, [pgdt + 2]
    or dword [es:ebx + 0x10 + 4], 0x80000000
    or dword [es:ebx + 0x18 + 4], 0x80000000
    or dword [es:ebx + 0x20 + 4], 0x80000000
    or dword [es:ebx + 0x28 + 4], 0x80000000
    or dword [es:ebx + 0x30 + 4], 0x80000000
    or dword [es:ebx + 0x38 + 4], 0x80000000                     
     
    add dword [pgdt + 2], 0x80000000
    
    lgdt [pgdt]
    jmp core_code_seg_sel:flush    ; 刷新CS寄存器，启用高端线性地址
    
 flush:
    mov eax, core_stack_seg_sel
    mov ss, eax
    
    mov eax, core_data_seg_sel
    mov ds, eax

    mov ebx, message_1
    call sys_routine_seg_sel:put_string
         
    ; setup call gate
    mov ecx, salt_items
    mov edi, salt
 .stgate:
    push ecx
    
    mov eax, [edi + 256]
    mov bx, [edi + 260]
    mov cx, 1_11_0_1100_000_00000b 
    call sys_routine_seg_sel:make_gate_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    or cx, 0x03      ; Ring3 可以访问     
    mov word [edi + 260], cx
    
    add edi, salt_item_len
    pop ecx
    loop .stgate
    
    mov ebx, message_2         ; gate call
    call far [salt + 256] 
 
    ; 分配内核任务
    mov ebx, [core_next_laddr]
    call sys_routine_seg_sel:alloc_inst_a_page
    add dword [core_next_laddr], 4096
    
    mov word [es:ebx + 0], 0
    mov eax, cr3
    mov dword [es:ebx + 28], eax ; TSS中CR3字段(PDBR)设置为CR3中的值 
    
    ; 填充TSS中的必要内容
    mov word [es:ebx + 96], 0    ; LDT 描述符字段设为0
    mov word [es:ebx + 100], 0   ; T=0    
    mov word [es:ebx + 102], 103 ; I/O位图，0特权级不需要
                                 ; 其他特权级的堆栈也不需要
                                                                  
    ; 创建TSS描述符，安装GDT
    mov eax, ebx
    mov ebx, 103
    mov ecx, 0x00408900  
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [prgman_tss+0x04], cx    ; 程序管理器的TSS描述符选择子
    
    ; 任务寄存器TR中内容是任务存在标志，决定了当前任务是谁
    ; 下面指令为当前正在执行的0特权级，任务管理器 补充TSS内容 
    ltr cx    


    ;============================================

    ; 分配 TCB 
    mov ecx, 0x46
    call sys_routine_seg_sel:allocate_memory
    call append_to_tcb_link
    ; 加载用户程序，压栈 用户程序的LBA/加载地址 
    push app_prog_lba      ; 
    push ecx
    call load_relocate_program

    ;mov ebx, do_status         ; Done.
    ;call sys_routine_seg_sel:put_string
    
    call far [es:ecx+0x14]    ; 执行任务切换，和上一章不同，任务切换时要恢复TSS内容
                              ; 所以在创建任务时TSS要填写完整 
    ; 重新加载并切换任务
    ;mov ebx, prgman_msg2
    ;call sys_routine_seg_sel:put_string
    
    hlt

core_code_end:
    
SECTION core_trail

core_end: