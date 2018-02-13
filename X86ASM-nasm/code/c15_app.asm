;
; Application
;
SECTION app_header align=16 vstart=0x0000
    app_legth    dd  app_end
    head_len     dd  header_end
    
    stack_seg    dd  0
    stack_len    dd  1
    
    code_entry   dd  start 
    code_seg     dd  section.app_code.start
    code_len     dd  code_end
    
    data_seg     dd  section.data.start
    data_len     dd  data_end    
        
    salt_items   dd  (header_end-salt) / 256
    ; Reloc table
 salt:    
    PrintString      db '@PrintString'
                     times 256 - ($-PrintString) db 0
    TerminateProgram db '@TerminateProgram'
                     times 256 - ($-TerminateProgram) db 0
    ReadDiskData     db '@ReadDiskData'
                     times 256 - ($-ReadDiskData) db 0     
header_end:

SECTION data vstart=0
    buffer times 1024 db 0
    message_1         db 0x0d, 0x0a, 0x0d, 0x0a
                      db '***********User program is running***********'
                      db 0x0d, 0x0a, 0
    message_2         db '    Disk data:', 0x0d, 0x0a, 0
data_end:

[bits 32]
SECTION app_code align=16 vstart=0x0000

start:
    mov eax, ds
    mov fs, eax
        
    mov eax, dword [stack_seg]
    mov ss, eax
    mov esp, 0
    
    mov eax, dword [data_seg]
    mov ds, eax    
    
    mov ebx, message_1
    call far [fs:PrintString]
    
    mov eax, 30
    mov edi, buffer
    call far [fs:ReadDiskData]
    
    mov ebx, message_2
    call far [fs:PrintString]
    
    mov ebx, buffer
    call far [fs:PrintString]
    
    jmp far [fs:TerminateProgram]
code_end:
                
SECTION app_tail
app_end:    