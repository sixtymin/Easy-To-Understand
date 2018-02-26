;
; Application
;
    app_legth    dd  app_end    
    code_entry   dd  start 
    salt_pos     dd  salt          
    salt_items   dd  (header_end-salt) / 256    
    ; Reloc table
 salt:    
    PrintString      db '@PrintString'
                     times 256 - ($-PrintString) db 0
    TerminateProgram db '@TerminateProgram'
                     times 256 - ($-TerminateProgram) db 0

    ReadDiskData     db '@ReadDiskData'
                     times 256 - ($-ReadDiskData) db 0
    PrintDwordAsHex  db '@PrintDwordAsHexString'
                     times 256 - ($-PrintDwordAsHex) db 0
                                          
 header_end:

    message_0         db '  User Task A->;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; '
                      db 0x0d, 0x0a, 0
                      
    space             db 0x20, 0x20, 0 
data_end:

[bits 32]

start:
    mov ebx, message_0
    call far [PrintString]
    
    jmp start
    
    call far [TerminateProgram]
code_end:

app_end:    