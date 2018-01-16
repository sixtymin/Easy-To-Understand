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
    code2seg  dd section.code2.start
    data2seg  dd section.data2.start
    stackseg  dd section.stack.start
    header_end db 0 
    
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

start:
    mov ax, [stackseg]    ; 切换栈 
    mov ss, ax
    mov sp, 256
    
    mov ax, [data1seg] 
    mov ds, ax
    
    call screen_cls       ; 清屏
    xor bx, bx
    call set_cursor_pos
    
    mov bx, msg0
    ;call put_sting
    mov cx, 0x20
    
 int10:
    mov ah, 0x0e
    mov al, [bx]
    int 0x10
    inc bx
    loop int10

 .reps:
    mov ah, 0x00
    int 0x16
    
    mov ah, 0x0e  ; int 0x16 执行完了，键盘输入字符就在al中 
    mov bl, 0x07
    int 0x10
    jmp .reps    
    
    jmp $            

SECTION data1 align=16 vstart=0

    msg0 db 0x0d,0x0a,'  This is NASM - the famous Netwide Assembler. '
         db 'Back at SourceForge and in intensive development! '
         db 'Get the current versions from http://www.nasm.us/.'
         db 0x0d,0x0a,0x0d,0x0a
         db '  Example code for calculate 1+2+...+1000:',0x0d,0x0a,0x0d,0x0a
         db '     xor dx,dx',0x0d,0x0a
         db '     xor ax,ax',0x0d,0x0a
         db '     xor cx,cx',0x0d,0x0a
         db '  @@:',0x0d,0x0a
         db '     inc cx',0x0d,0x0a
         db '     add ax,cx',0x0d,0x0a
         db '     adc dx,0',0x0d,0x0a
         db '     inc cx',0x0d,0x0a
         db '     cmp cx,1000',0x0d,0x0a
         db '     jle @@',0x0d,0x0a
         db '     ... ...(Some other codes)',0x0d,0x0a,0x0d,0x0a
         db 0

;===============================================================================         
SECTION code2 align=16 vstart=0

code2_start:
    mov bx, prgoff
    push es
    push di
    mov ax, 0xb800
    mov es, ax
    xor di, di
    mov ah, 0x04
    mov al, '@'
    mov [es:di], ax
    pop di
    pop es
    push word [es:bx + 0x2]
    push word [es:bx]    
    retf 

SECTION data2 align=16 vstart=0

    msg1 db '  The above contents is written by LeeChung. '
         db '2011-05-06'
         db 0
;===============================================================================
SECTION stack align=16 vstart=0
    resb 256
    
;===============================================================================
SECTION trail align=16

    program_end: