;
; Application
;
[bits 32]

SECTION app_header align=16 vstart=0x0000
    app_legth    dd  app_end
    app_code     dd  section.app_code.start
    app_code_seg dd  0x00000000
    
    ; Reloc table
    printstr db '@PrintString'
             times 256 - ($-salt_1) db 0
    
SECTION app_code align=16 vstart=0x0000

SECTION app_tail
app_end:    
    


