;
; Core
;

app_prog_lba       equ     10   ; 应用程序所在的起始扇区号

[bits 32]

SECTION core_header align=16 vstart=0
    core_length     dd  core_end
    sys_funcs_off   dd  section.sys_routine.start    
    sys_seg         dd  0
    coredata_off    dd  section.core_data.start
    coredata_seg    dd  0
    corecode_off    dd  section.core_code.start
    corecode_seg    dd  0
    
    salt_1 db '@PrintString'
           times 256 - ($-salt_1) db 0
           dd put_string
           dw sys_routing_seg_sel
              
SECTION sys_routine align=16 vstart=0

SECTION core_data align=16 vstart=0

SECTION core_code align=16 vstart=0

SECTION core_trail

core_end: