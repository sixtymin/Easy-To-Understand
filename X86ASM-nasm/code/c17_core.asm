;
; Core
;
app_prog1_lba      equ     20   ; 应用程序1 所在的起始扇区号
app_prog2_lba      equ     30   ;
app_prog_startoff  equ     0x10 ; 应用程序起始偏移 

flat_4gb_data_seg_sel  equ    0x10
flat_4gb_code_seg_sel  equ    0x08
idt_linear_address     equ    0x8001f000
video_ram_address      equ    0x800B8000

; 
%macro alloc_core_linear 0
    mov ebx, [core_tcb+0x06]
    add dword [core_tcb+0x06], 0x1000
    call flat_4gb_code_seg_sel:alloc_inst_a_page
%endmacro

%macro alloc_user_linear 0
    mov ebx, [esi+0x06]
    add dword [esi+0x06], 0x1000
    call flat_4gb_code_seg_sel:alloc_inst_a_page
%endmacro 
   
SECTION core align=16 vstart=0x80040000
    core_lenght   dd core_end     ; 程序总长度 
    core_entry    dd start        ; 核心代码起始地址 
;
    [bits 32]

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
    pushad
        
    xor eax, eax    
    call get_cursor_pos
    mov ebx, eax
    
    cmp cl, 0x0d
    jz put_0d
    cmp cl, 0x0a
    jz put_0a
    
    shl ebx, 1  ; 输出正常字符
    mov [ebx + video_ram_address], cl
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
    add edi, video_ram_address
    mov esi, 0xa0
    add esi, video_ram_address    
    mov ecx, 1920
    rep movsw

    mov eax, 0x20
    mov ecx, 80
  cls_ln:
    mov byte [edi + video_ram_address], al
    add edi, 2
    loop cls_ln

    mov ebx, 1920   ; 设置光标位置

  reset_cur: 
    call set_cursor_pos

    popad
    ret      
;
; Show a string(zero end) on screen
; param:
;   EBX  指向要输出字符串（0结束符）基地址 
put_string:

    cli
    
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
    
    sti    
    
    retf    
;
; clean screen 
;
screen_cls:
    push ecx
    push edi
    push eax
        
    mov edi, video_ram_address
    mov ecx, 2000
    mov eax, 0x0720
mov_word:    
    mov [edi], ax
    add edi, 2
    loop mov_word 
    
    pop eax
    pop edi
    pop ecx
    retf 

;
; read a section from disk
; EAX: section no.  EDI: memory buffer
read_hard_disk_section:
    
    cli
    
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
    
    sti
    
    retf

; 
; For debug, output DWORD
;
put_hex_dword:
    
    pushad
    
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
  
    popad
    retf


; EDX:EAX - [IN]  descriptor item
; CX - [OUT] selector
;
set_up_gdt_descriptor:
    push eax
    push ebx 
    push edx
    
    sgdt [pgdt]
    
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
;
;
;
terminate_current_task:
        
    mov eax, tcb_chain
 .b0:
    mov ebx, [eax]
    cmp word [ebx+0x04], 0xffff
    je .b1
    mov eax, ebx
    jmp .b0
    
 .b1: 
    mov word [ebx+0x04], 0x3333
 .b2:
    hlt
    jmp .b2

;
; 分配一个4K的页 
; EAX=页的物理地址 
allocate_a_4k_page:
   
   push ebx
   push ecx
   push edx
   
   xor eax, eax
 .b1:
   bts [page_bit_map], eax
   jnc .b2
   inc eax
   cmp eax, page_map_len*8
   jl .b1
   
   mov ebx, message_3
   call flat_4gb_code_seg_sel:put_string
   hlt
   
 .b2:
   shl eax, 12
   
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

    pop esi
    pop ebx
    pop eax
    
    retf   
    
create_copy_cur_pdir:

    push esi
    push edi
    push ebx 
    push ecx
    
    call allocate_a_4k_page
    mov ebx, eax
    or ebx, 0x00000007
    mov [0xFFFFFFF8], ebx
    
    invlpg [0xFFFFFFF8]
    
    mov esi, 0xFFFFF000
    mov edi, 0xFFFFE000
    mov ecx, 1024
    cld
    repe movsd    
    
    pop ecx
    pop ebx 
    pop edi
    pop esi
    retf        

; 通用中断处理过程 
general_interrupt_handler:
    push eax
    
    mov al, 0x20   ;中断结束命令 EOI 
    out 0xa0, al   ; 向主片发送 
    out 0x20, al   ; 向从片发送 
    
    pop eax
    
    iretd    

; 通用异常处理过程
general_exception_handler:
    mov ebx, excep_msg
    call flat_4gb_code_seg_sel:put_string
    hlt    

rtm_0x70_interrupt_handle:
    
    pushad
    
    mov al, 0x20
    out 0xa0, al
    out 0x20, al
    
    mov al, 0x0c
    out 0x70, al
    in al, 0x71
    
    mov eax, tcb_chain
    
 .b0:
    mov ebx, [eax]
    or ebx, ebx
    jz .irtn
    cmp word [ebx+0x04], 0xffff
    je .b1
    mov eax, ebx
    jmp .b0
    
 .b1:
    mov ecx, [ebx]     ; 找到忙节点，从链表拆除 
    mov [eax], ecx 
 .b2:
    mov edx, [eax]
    or edx, edx
    jz .b3
    mov eax, edx       ; 继续寻找最后一个节点 
    jmp .b2
 
 .b3:
    mov [eax], ebx     ; 找到结尾节点，将EBX中的忙节点挂入 
    mov dword [ebx], 0x00000000
    
    mov eax, tcb_chain  ; 寻找空闲结点 
 .b4:
    mov eax, [eax]
    or eax, eax
    jz .irtn
    cmp word [eax+0x04], 0x0000
    jnz .b4
    
    not word [eax+0x04]    ; 找到空闲结点，则置状态 
    not word [ebx+0x04]
    jmp far [eax + 0x14]   ; 任务切换
    
 .irtn:
    popad
    
    iretd                 
    
;======================================
; data    
    pgdt      dw   0
              dd   0
    pidt      dw   0
              dd   0
    
    tcb_chain dd   0
    core_tcb times 32 db 0    ; 内核的TCB 
              
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
              
    ; 检索表
    salt:
    salt_1    db   '@PrintString'
              times 256-($-salt_1) db 0
              dd   put_string
              dw   flat_4gb_code_seg_sel
    salt_2    db   '@ReadDiskData'
              times 256-($-salt_2) db 0
              dd   read_hard_disk_section
              dw   flat_4gb_code_seg_sel
    salt_3    db   '@PrintDwordAsHexString'
              times 256-($-salt_3) db 0
              dd   put_hex_dword
              dw   flat_4gb_code_seg_sel
    salt_4    db   '@TerminateProgram'
              times 256-($-salt_4) db 0
              dd   terminate_current_task
              dw   flat_4gb_code_seg_sel
    
    salt_item_len equ $-salt_4
    salt_items    equ 4;($-salt)/salt_item_len

    excep_msg db '*****Exception encounted*****', 0

    message_0 db ' Working in system core, protect mode.'
              db 0x0d,0x0a,0
    
    message_1 db ' Paging is enabled. System core is mapped to'
              db ' address 0x80000000.',0x0d,0x0a,0
    message_2 db 0x0d,0x0a 
              db ' System wide CALL-GATE mounted.',0x0d,0x0a,0

    message_21 db 0x0d,0x0a, ' Running in Program Manager.',0x0d,0x0a,0
    
    message_3 db '********No more pages********',0
    
    core_msg0  db ' System core task running', 0x0d, 0x0a, 0
                  
    bin_hex db '0123456789ABCDEF'
    
    core_buf times 2048 db 0
    
    cpu_brand0 db 0x0d,0x0a,' ',0
    cpu_brand times 64 db 0
    cpu_brand1 db 0x0d,0x0a,0x0d,0x0a,0    
                   
core_data_end:

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
    
    mov ebp, esp       ; 为访问栈上参数准备基准值 
    
    ; 清空当前页目录的前半部分
    mov ebx, 0xFFFFF000
    xor esi, esi
 .b1:
    mov dword [ebx + esi*4], 0x00000000
    inc esi
    cmp esi, 512
    jl .b1     
    
    mov eax, cr3
    mov cr3, eax     
                
    ; load user program to memory
    mov eax, [ebp+10*4]  ; 用户程序起始 LBA    
    mov edi, core_buf
    call flat_4gb_code_seg_sel:read_hard_disk_section     ; get header
    
    mov eax, dword [core_buf]
    mov ebx, eax
    and ebx, 0xFFFFF000
    add ebx, 0x1000
    test eax, 0x00000FFF    ; 两个操作数进行 与 运算，置位EFLAGS标记 
    cmovnz eax, ebx

    mov ecx, eax
    shr ecx, 12    ; 计算需要有多少页 
        
    push edi
    mov esi, [ebp+9*4]    ; TCB 基地址    
    mov eax, [ebp+10*4]     ; 其实扇区号 LBA 
 .b2:
    alloc_user_linear     ; 宏：在用户任务地址空间上分配内存 
    
    mov edi, ebx
    push ecx
    mov ecx, 8
 .b3:
    call flat_4gb_code_seg_sel:read_hard_disk_section 
    inc eax
    add edi, 512
    loop .b3
    
    pop ecx    
    loop .b2
    pop edi
     
    alloc_core_linear         ; 内核空间创建用户的TSS 
    
    mov [esi+0x14], ebx        ; TCB中TSS线性地址 
    mov word [esi+0x12], 103   ; TCB中TSS界限 
    
    ;建立程序代码段     0x00
    alloc_user_linear 
    mov [esi + 0x0c], ebx    
     
    xor eax, eax
    mov ebx, 0x000FFFFF     ; seg len
    mov ecx, 0x00C0F800    ; attributes
    call flat_4gb_code_seg_sel:make_seg_descriptor    
    mov ebx, esi
    call fill_descriptor_in_ldt       ; 安装到LDT中      
    or cx, 0000_0000_0000_0011B    ; 权限值设为 3 
    mov ebx, [esi+0x14]
    mov [ebx + 76], cx 
        
    ;建立程序数据段描述符   0x07
    xor eax,eax
    mov ebx,0x000FFFFF                 ;段长度
    mov ecx,0x00C0F200                 ;字节粒度的数据段描述符
    call flat_4gb_code_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    or cx, 0000_0000_0000_0011B
    mov ebx, [esi+0x14]
    mov [ebx + 84], cx       ; TSS DS域
    mov [ebx + 72], cx       ; TSS ES域
    mov [ebx + 88], cx       ; TSS FS域
    mov [ebx + 92], cx       ; TSS GS域                 

    ;建立程序堆栈段描述符   0x0F
    alloc_user_linear
       
    mov ebx, [esi + 0x14]
    mov [ebx + 80], cx       ; TSS SS域
    mov edx, [esi+0x06]      ; 刚为栈段 分配的内存段的高地址，即下一个即将分配的地址 
    mov [ebx+56], edx        ; TSS ESP域
      
    cld

    mov edi, [0x08]              ;用户程序内的SALT位于头部内0x2c处
    mov ecx, [0x0c]              ;用户程序的SALT条目数    
  .b4: 
    push ecx
    push edi
      
    mov ecx, salt_items
    mov esi, salt
  .b5:
    push edi
    push esi
    push ecx

    mov ecx,64                         ;检索表中，每条目的比较次数 
    repe cmpsd                         ;每次比较4字节 
    jnz .b6
    mov eax,[esi]                      ;若匹配，esi恰好指向其后的地址数据
    mov [edi-256],eax               ;将字符串改写成偏移地址 
    mov ax,[esi+4]
    or ax, 0000000000000011B        ; RPL=3
    mov [edi-252],ax                ;以及段选择子 
  .b6:
      
    pop ecx
    pop esi
    add esi,salt_item_len
    pop edi                            ;从头比较 
    loop .b5
      
    pop edi
    add edi,256
    pop ecx
    loop .b4

    
    mov esi, [ebp + 9*4]
    alloc_user_linear
    
    mov eax, 0x00000000
    mov ebx, 0x000FFFFF
    mov ecx, 0x00C09200       ; 4K粒度，特权级0
    call flat_4gb_code_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    
    mov ebx, [esi+0x14]
    mov [ebx+8], cx
    mov edx, [esi+0x06]
    mov [ebx+4], edx 
    
    ;创建1特权级堆栈
    alloc_user_linear
    
    mov eax, 0x00000000
    mov ebx, 0x000FFFFF
    mov ecx, 0x00C0B200                 ;4KB粒度，读写，特权级1
    call flat_4gb_code_seg_sel:make_seg_descriptor
    mov ebx, esi                        ;TCB的基地址
    call fill_descriptor_in_ldt
    or cx, 0000_0000_0000_0001B         ;设置选择子的特权级为1
    
    mov ebx, [esi+0x14]             ; TSS 基地址
    mov [ebx + 16], cx
    mov edx, [esi+0x06]             ; 堆栈高端地址
    mov [ebx + 12], edx             ; TSS ESP1 

    ;创建2特权级堆栈
    alloc_user_linear

    mov eax, 0x00000000
    mov ebx, 0x000FFFFF
    mov ecx,0x00c0d200                 ;4KB粒度，读写，特权级1
    call flat_4gb_code_seg_sel:make_seg_descriptor
    mov ebx,esi                        ;TCB的基地址
    call fill_descriptor_in_ldt
    or cx,0000_0000_0000_0010B         ;设置选择子的特权级为1

    mov ebx, [esi+0x14]             ; TSS 基地址
    mov [ebx + 24], cx
    mov edx, [esi+0x06]             ; 堆栈高端地址
    mov [ebx + 20], edx             ; TSS ESP1

    ;在GDT中登记LDT描述符
    mov esi, [ebp + 9*4]
    mov eax, [esi+0x0c]             ;LDT的起始线性地址
    movzx ebx,word [esi+0x0a]       ;LDT段界限
    mov ecx,0x00408200                 ;LDT描述符，特权级0
    call flat_4gb_code_seg_sel:make_seg_descriptor
    call flat_4gb_code_seg_sel:set_up_gdt_descriptor
    mov [esi+0x10],cx               ;登记LDT选择子到TCB中
    
    mov ebx, [esi+0x14]
    mov [ebx + 96], cx              ; TSS中 LDT域 
    mov word [ebx + 0], 0           ; 反向链
    
    mov dx, [esi + 0x12]            ; 段长度
    mov [ebx + 102], dx
    mov word [ebx + 100], 0         ; T = 0
    
    mov eax, [0x04]
    mov [ebx + 32], eax             ; EIP 
    
    pushfd 
    pop edx
    mov [ebx + 36], edx             ; TSS的EFLAGS
               
    ;在GDT中登记TSS描述符
    mov eax,[esi+0x14]              ;TSS的起始线性地址
    movzx ebx,word [esi+0x12]       ;段长度（界限）
    mov ecx,0x00408900                 ;TSS描述符，特权级0
    call flat_4gb_code_seg_sel:make_seg_descriptor
    call flat_4gb_code_seg_sel:set_up_gdt_descriptor
    mov [esi+0x18],cx               ;登记TSS选择子到TCB
    
    ; 复制页目录和页表
    call flat_4gb_code_seg_sel:create_copy_cur_pdir
    mov ebx, [esi+0x14]
    mov dword [ebx+28], eax 
            
    popad
    ret 8
    
;
; ECX=tcb基地址 
;
append_to_tcb_link:
    
    cli    ; 关中断 
    
    push eax
    push edx        
    
    mov eax, tcb_chain
 .searc:
    mov edx, [eax]
    or edx, edx
    jz .notcb
       
    mov eax, edx
    jmp .searc
 .notcb:
    mov [eax], ecx ; 空表，直接将头指针指向新分配
    mov dword [ecx], 0x00000000 ; TCB指针域清0，最后一个TCB
     
    pop edx
    pop eax
    
    sti      ; 开中断 
    
    ret    
    
    ;
    ; Core Start Address
    ;
start:
    ; 创建中断描述符表 IDT
    ; 在此之前不能调用含有 sti 指令过程
    
    call flat_4gb_code_seg_sel:screen_cls  ; 清屏

    xor ebx, ebx
    call flat_4gb_code_seg_sel:far_set_cursor_pos ; 设置光标位置    
    
    ; 前20个向量处理器异常
    mov eax, general_exception_handler
    mov bx, flat_4gb_code_seg_sel
    mov cx, 0x8e00    ;  32位门中断，0特权级别
    call flat_4gb_code_seg_sel:make_gate_descriptor
    
    mov ebx, idt_linear_address     ; 这块内存在1M之内，已经被分配（分页和物理内存） 
    xor esi, esi
 .idt0:
    mov [ebx + esi*8], eax
    mov [ebx + esi*8 + 4], edx
    inc esi
    cmp esi, 19
    jle .idt0
    
    mov eax, general_interrupt_handler
    mov bx, flat_4gb_code_seg_sel
    mov cx, 0x8e00
    call flat_4gb_code_seg_sel:make_gate_descriptor
    
    mov ebx, idt_linear_address
 .idt1:
    mov [ebx+esi*8], eax
    mov [ebx+esi*8+4], edx
    inc esi
    cmp esi, 255
    jle .idt1
    
    ; 实时时钟中断处理过程
    mov eax, rtm_0x70_interrupt_handle
    mov bx, flat_4gb_code_seg_sel
    mov cx, 0x8e00
    call flat_4gb_code_seg_sel:make_gate_descriptor
    
    mov ebx, idt_linear_address
    mov [ebx+0x70*8], eax
    mov [ebx+0x70*8+4], edx
    
    ; 开放中断
    mov word [pidt], 256*8-1
    mov dword [pidt+2], idt_linear_address
    lidt [pidt]
    
    ; 设置8259A中断控制器
    mov al, 0x11       ; ICW1, 边沿触发，级联方式 
    out 0x20, al
    mov al, 0x20       ; ICW2 起始中断向量 
    out 0x21, al
    mov al, 0x04       ; ICW3 从片级联到IR2 
    out 0x21, al
    mov al, 0x01       ; ICW4 非总线缓冲，全嵌套，正常EOI     
    out 0x21, al     
    
    mov al, 0x11       ; ICW1, 边沿触发，级联方式
    out 0xa0, al
    mov al, 0x70       ; ICW2 起始中断向量
    out 0xa1, al
    mov al, 0x04       ; ICW3 从片级联到IR2
    out 0xa1, al
    mov al, 0x01       ; ICW4 非总线缓冲，全嵌套，正常EOI
    out 0xa1, al
    
    ; 设置和时钟中断相关的硬件
    mov al, 0x0b       ; RTC寄存器B
    or al, 0x80        ; NMI阻断
    out 0x70, al
    mov al, 0x12       ; 设置寄存器B，禁止周期性中断，开放更新结束后中断
    out 0x71, al       ; BCD 码，24小时制    
     
    in al, 0xa1        ; 读8259从片的IMR寄存器
    and al, 0xfe       ; 清除bit 0
    out 0xa1, al       ; 写回寄存器
    
    mov al, 0x0c
    out 0x70, al
    in al, 0x71        ; 读取RTC寄存器C，复位未决的中断状态
     
    sti  ; 开放硬件中断
        
    mov ebx, message_0   
    call flat_4gb_code_seg_sel:put_string 
           
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
    call flat_4gb_code_seg_sel:put_string
    mov ebx, cpu_brand
    call flat_4gb_code_seg_sel:put_string    
    mov ebx, cpu_brand1
    call flat_4gb_code_seg_sel:put_string
         
    ; setup call gate
    mov ecx, salt_items
    mov edi, salt
 .stgate:
    push ecx    
    mov eax, [edi + 256]
    mov bx, [edi + 260]
    mov cx, 1_11_0_1100_000_00000b 
    call flat_4gb_code_seg_sel:make_gate_descriptor
    call flat_4gb_code_seg_sel:set_up_gdt_descriptor
    ;or cx, 0x0003      ; Ring3 可以访问     
    mov word [edi + 260], cx
    
    add edi, salt_item_len
    pop ecx
    loop .stgate
    
    mov ebx, message_2         ; gate call
    call far [salt + 256] 
 
    ; 分配内核任务
    mov word [core_tcb+0x04], 0xffff      ; 状态忙碌
    mov dword [core_tcb+0x06], 0x80100000
    
    mov word [core_tcb+0x0a], 0xffff      ; 登记LDT初始的界限为未使用
    mov ecx, core_tcb
    call append_to_tcb_link               ; 添加到TCB链中
    
    alloc_core_linear   ; 宏，在内核虚拟地址空间分配内存 
        
    mov word [ebx + 0], 0
    mov eax, cr3
    mov dword [ebx + 28], eax ; TSS中CR3字段(PDBR)设置为CR3中的值 
    
    ; 填充TSS中的必要内容
    mov word [ebx + 96], 0    ; LDT 描述符字段设为0
    mov word [ebx + 100], 0   ; T=0    
    mov word [ebx + 102], 103 ; I/O位图，0特权级不需要
                                 ; 其他特权级的堆栈也不需要
                                                                  
    ; 创建TSS描述符，安装GDT
    mov eax, ebx
    mov ebx, 103
    mov ecx, 0x00408900  
    call flat_4gb_code_seg_sel:make_seg_descriptor
    call flat_4gb_code_seg_sel:set_up_gdt_descriptor
    mov [core_tcb+0x14], cx    ; 程序管理器的TSS描述符选择子
    
    ; 任务寄存器TR中内容是任务存在标志，决定了当前任务是谁
    ; 下面指令为当前正在执行的0特权级，任务管理器 补充TSS内容 
    ltr cx    

    ; 加载了 tss，则认为"程序管理器"任务在执行中 
    mov ebx, message_21
    call flat_4gb_code_seg_sel:put_string

    ; 分配 任务1 TCB
    alloc_core_linear
    
    mov word [ebx+0x04], 0           ; 任务状态：空闲 
    mov dword [ebx+0x06], 0          ; 起始可用的虚拟地址 
    mov word [ebx+0x0a], 0xffff
        
    ; 加载用户程序，压栈 用户程序的LBA/加载地址 
    push app_prog1_lba      ; 
    push ebx
    call load_relocate_program
    mov ecx, ebx
    call append_to_tcb_link 

    ; 分配 任务2 TCB
    alloc_core_linear

    mov word [ebx+0x04], 0           ; 任务状态：空闲
    mov dword [ebx+0x06], 0          ; 可用的起始虚拟地址 
    mov word [ebx+0x0a], 0xffff

    ; 加载用户程序，压栈 用户程序的LBA/加载地址
    push app_prog2_lba      ;
    push ebx
    call load_relocate_program
    mov ecx, ebx
    call append_to_tcb_link
    
 .core: 
    mov ebx, core_msg0 
    call flat_4gb_code_seg_sel:put_string
    
    jmp .core 

core_code_end:
    
SECTION core_trail

core_end: