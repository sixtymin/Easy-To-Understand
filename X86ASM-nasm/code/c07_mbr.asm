; 没有指定程序起始地址，则默认从地址 0x00000000 上开始
    jmp near start    
    ;message db '1','+','2','+','3','+','.','.','.','+','1','0','0',' ','=',' '
    message db '1+2+3+...+100 = '
        
start: 
    mov ax, 0xB800    ; 视频缓存起始地址，0x0B800 
    mov es, ax
    mov ax, 0x07C0
    mov ds, ax

    xor ax, ax         ; 输出 message字符串 
    mov si, message
    xor di, di 
    mov ah, 0x07
    mov cx, (start - message)       
show1:
    mov al, byte [si]
    mov [es:di], ax
    add di, 2
    inc si
    loop show1

    mov cx, 1           ; 计算1到100的和 
    xor ax, ax
sum:
    add ax, cx
    inc cx
    cmp cx, 100
    jna sum
    
    xor cx, cx          ; 将和进行分解 
    mov ss, cx
    mov sp, 0x7c00
    
    mov si, 10
digit:
    xor dx, dx
    div si
    or dl, 0x30
    push dx
    inc cx
    cmp ax, 0
    jne digit
    
show2:                  ; 将和的结果输出到界面 
    pop dx
    mov dh, 0x04
    mov [es:di], dx
    add di, 2
    loop show2           
    
    mov byte [es:di], 'd' ; 输出最后的字母d，表示10进制 
    inc di
    mov byte [es:di], 0x04
    
infi:
    jmp near infi
;    jmp near $                 
    
    times 510 - ($-$$) db 0
    db 0x55, 0xaa