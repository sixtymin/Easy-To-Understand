;
; program
;       
SECTION header align=16 vstart=0
    prgsize   dd program_end          ; program size
    prgoff    dw start
    prgstart  dd section.code1.start  ; program start address
    relitems  dw (header_end - code1seg) / 4
    code1seg  dd section.code1.start
    data1seg  dd section.data1.start
    stackseg  dd section.stack.start
    header_end: 
    
SECTION code1 align=16 vstart=0

;
; bx save pos info
;
set_cursor_pos:
    push dx
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
    pop dx
    ret
;
; ax return pos info
;
get_cursor_pos:
    push dx
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
    pop dx
    ret

;
; Show a char on screen
; cx : outpu char value
put_char:
    push es
    push ds 
    push si
    push di
    push dx
    push bx
    
    mov ax, 0xb800
    mov es, ax
    mov ds, ax
        
    call get_cursor_pos
    mov bx, ax
    
    cmp cl, 0x0d
    jz put_0d
    cmp cl, 0x0a
    jz put_0a
    
    shl bx, 1  ; 输出正常字符
    mov [es:bx], cl
    shr bx, 1
    inc bx
    jmp crll_screen  ; 是否卷屏 
     
  put_0d:    
    mov ax, bx
    mov bl, 80
    div bl
    xor ah, ah
    mul bl
    mov bx, ax   
    jmp reset_cur  
  put_0a:
    add bx, 80
  crll_screen:
    cmp bx, 2000
    jb reset_cur

    xor di, di  ; 卷屏
    mov si, 0xa0
    mov cx, 1920
    rep movsw

    mov al, 0x20
    mov cx, 80
  cls_ln:
    mov [es:di], al
    add di, 2
    loop cls_ln

    mov bx, 1920   ; 设置光标位置

  reset_cur: 
    call set_cursor_pos

    pop bx    
    pop dx
    pop di
    pop si
    pop ds
    pop es
    ret      
;
; Show a string(zero end) on screen
; param:
;   DS:BX  指向要输出字符串（0结束符）基地址 
put_sting:
    push cx
    xor ax, ax
  more:
    mov al, [ds:bx]
    cmp al, 0
    jz none
    mov cl, al
    call put_char
    inc bx    
    jmp more    
  none:
    pop cx
    ret    
;
; clean screen 
;
screen_cls:
    push es
    push cx
    push di
    
    xor di, di    
    mov ax, 0xB800
    mov es, ax
    mov cx, 2000
    mov ax, 0x0720
mov_word:    
    mov [es:di], ax
    add di, 2
    loop mov_word 
    
    pop di
    pop cx
    pop es
    ret 

;
; param: ax
;
bcd_to_ascii:
    mov ah, al
    shr ah, 4
    or ah, 0x30
    and al, 0x0F
    or al, 0x30
    ret 
    
;
; New Int 0x70
; 
new_int_0x70:
    push ax
    push bx
    push cx
    push dx
    push es
    
 .w0:
    mov al, 0x0a
    or al, 0x80
    out 0x70, al
    in al, 0x71
    test al, 0x80
    jnz .w0
    
    xor al, al
    or al, 0x80
    out 0x70, al
    in al, 0x71
    push ax
    
    mov al, 2
    or al, 0x80
    out 0x70, al
    in al, 0x71
    push ax
    
    mov al, 4
    or al, 0x80
    out 0x70, al
    in al, 0x71
    push ax
    
    mov al, 0x0c
    out 0x70, al
    in al, 0x71
    
    mov ax, 0xb800
    mov es, ax
    
    pop ax
    call bcd_to_ascii
    mov bx, 11*160 + 35*2
    
    mov [es:bx], ah
    mov [es:bx+2], al
    
    mov al, ':'
    mov [es:bx+4], al
    not byte [es:bx+5]
    
    pop ax
    call bcd_to_ascii
    mov [es:bx+6], ah
    mov [es:bx+8], al
    
    mov al, ':'
    mov [es:bx +10], al
    not byte [es:bx + 11]
    
    pop ax
    call bcd_to_ascii
    mov [es:bx+12], ah
    mov [es:bx+14], al
    
    mov al, 0x20    ; 中断结束命令 EOI 
    out 0xa0, al    ; 8259 主片和从片 
    out 0x20, al
    
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    iret 

start:
    mov ax, [stackseg]    ; 切换栈 
    mov ss, ax
    mov sp, stack_end

    mov ax, [data1seg]
    mov ds, ax
    call screen_cls       ; 清屏
    xor bx, bx
    call set_cursor_pos   ; 重置光标位置
    mov bx, msg0
    call put_sting        ; 输出字符串
    
    cli
    
    push es
    xor ax, ax
    mov es, ax
    
    mov ax, cs
    mov [es:0x1c2], ax
    mov ax, new_int_0x70    
    mov [es:0x1c0], ax
    pop es
    
    mov al, 0xb
    or al, 0x80
    out 0x70, al

    ; 00010010 允许更新周期发生，禁止周期性中断，禁止闹钟，
    ; 允许更新周期结束中断，24小时制，日期时间用BCD编码    
    mov al, 0x12
    out 0x71, al
    
    mov al, 0xc
    out 0x70, al
    in al, 0x71
    
    in al, 0xa1
    and al, 0xfe
    out 0xa1, al
    
    sti   
    
    mov ax, 0xB800
    mov es, ax
    mov byte [es:0x722], '@'
    mov byte [es:0x723], 0x04    
    
    ;jmp $
  hlt_set:
    hlt      
    not byte [es:0x723]          
    jmp hlt_set             

SECTION data1 align=16 vstart=0

    msg0 db 'User Program Time:',
         db 0

;===============================================================================
SECTION stack align=16 vstart=0
    resb 256
    stack_end:
;===============================================================================
SECTION trail align=16

    program_end: