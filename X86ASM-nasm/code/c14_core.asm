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
    and ebx, 4
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
    
SECTION core_data align=16 vstart=0
    pgdt      dw   0
              dd   0
              
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
              dd   return_point
              dw   core_code_seg_sel
    
    salt_item_len equ $-salt_4
    salt_items    equ 4;($-salt)/salt_item_len
    
    message_1 db ' If you seen this message,that means we '
              db 'are now in protect mode,and the system '
              db 'core is loaded,and the video display '
              db 'routine works perfectly.',0x0d,0x0a,0
                   
    message_2 db ' Output string by call gate.', 0x0d, 0x0a, 0
    message_5 db ' Loading user program...',0
    
    do_status db 'Done.', 0x0d, 0x0a,0
                                
    message_6 db 0x0d,0x0a,0x0d,0x0a,0x0d,0x0a
              db ' User program terminated,control returned.',0
              
    bin_hex db '0123456789ABCDEF'
    
    core_buf times 2048 db 0
    
    esp_pointer dd 0 ;内核用来临时保存自己的栈指针
    
    cpu_brand0 db 0x0d,0x0a,' ',0
    cpu_brand times 52 db 0
    cpu_brand1 db 0x0d,0x0a,0x0d,0x0a,0    
    
SECTION core_code align=16 vstart=0

;
; load user program, and relocate
; [IN] 
;     ESI： start lba
; [OUT] 
;     EAX:  user app data seg 
load_relocate_program:
    push ebx
    push ecx
    push edx
    push edi
    push esi 
    push ds   
    push es
    
    mov eax,core_data_seg_sel
    mov ds,eax                         ;切换DS到内核数据段
    
    ; load user program to memory
    mov eax, esi    
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
    mov edi, ecx
    
    xor edx, edx
    mov ebx, 512
    div ebx
    
    mov ecx, eax
    mov eax, mem_0_4_gb_seg_sel
    mov ds, eax
    
    push edi
    mov eax, esi
 .b1:
    call sys_routine_seg_sel:read_hard_disk_section
    inc eax
    add edi, 512
    loop .b1
    
    ;建立程序头段描述符     0x40 
    pop edi
    mov eax, edi
    mov ebx, [edi+0x4]     ; seg len
    dec ebx
    mov ecx, 0x00409200    ; attributes
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [edi + 0x04], cx
    
    ;建立程序代码段描述符   0x48 
    mov eax,edi
    add eax,[edi+0x14]                 ;代码起始线性地址
    mov ebx,[edi+0x18]                 ;段长度
    dec ebx                            ;段界限
    mov ecx,0x00409800                 ;字节粒度的代码段描述符
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [edi+0x14],cx

    ;建立程序数据段描述符   0x50
    mov eax,edi
    add eax,[edi+0x1c]                 ;数据段起始线性地址
    mov ebx,[edi+0x20]                 ;段长度
    dec ebx                            ;段界限
    mov ecx,0x00409200                 ;字节粒度的数据段描述符
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [edi+0x1c],cx

    ;建立程序堆栈段描述符   0x58
    mov ecx,[edi+0x0c]                 ;4KB的倍率 
    mov ebx,0x000fffff
    sub ebx,ecx                        ;得到段界限
    mov eax,4096                        
    mul dword [edi+0x0c]                         
    mov ecx,eax                        ;准备为堆栈分配内存 
    call sys_routine_seg_sel:allocate_memory
    add eax,ecx                        ;得到堆栈的高端物理地址 
    mov ecx,0x00c09600                 ;4KB粒度的堆栈段描述符
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [edi+0x08],cx

    ;重定位SALT
    mov eax,[edi+0x04]
    mov es,eax                         ;es -> 用户程序头部 
    mov eax,core_data_seg_sel
    mov ds,eax
      
    cld

    mov ecx,[es:0x24]                  ;用户程序的SALT条目数
    mov edi,0x28                       ;用户程序内的SALT位于头部内0x2c处
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

    mov ax,[es:0x04]

    pop es                             ;恢复到调用此过程前的es段 
    pop ds                             ;恢复到调用此过程前的ds段
            
    pop esi
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret
    
    ;
    ; Core Start Address
    ;
start:
    mov ecx, core_data_seg_sel
    mov ds, ecx

    call sys_routine_seg_sel:screen_cls  ; 清屏
    
    xor ebx, ebx 
    call sys_routine_seg_sel:far_set_cursor_pos ; 设置光标位置 
    
    mov ebx, message_1
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
    
    mov ebx, message_2
    mov edi, salt
    call far [edi + 256] 

    mov ebx, message_5
    call sys_routine_seg_sel:put_string
  
    ; load user program
    mov esi, app_prog_lba
    call load_relocate_program

    mov ebx, do_status
    call sys_routine_seg_sel:put_string

    ; call user program
    mov [esp_pointer], esp
    mov ds, ax    
    jmp far [app_prog_startoff]        
return_point:
    mov eax, core_data_seg_sel
    mov ds, eax
    
    mov eax, core_stack_seg_sel
    mov ss, eax
    mov esp, [esp_pointer]
    
    mov ebx, message_6
    call sys_routine_seg_sel:put_string
    
    hlt
    
SECTION core_trail

core_end: