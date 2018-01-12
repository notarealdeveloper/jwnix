; The global descriptor table *register*
; ======================================
; The idea: The GDT is pointed to by a special register in the x86 chip, 
; the GDT Register, or simply the GDTR. The GDTR is 48 bits long. The 
; lower 16 bits tell the size of the GDT, and the upper 32 bits tell the 
; location of the GDT in memory. So below, the "dw" line is the gdt limit
; which is just the size of the gdt minus one. The "minus one" is because
; of that wonderful OBOE-causing fact that the highest bit in a byte is
; bit 7, since we start counting from zero. Sometimes I really hate
; having a primate brain... it gets confused by entirely trivial things.
; Anyway, our gdt register says (a) "Limit = Size of GDT - 1", which in 
; our case is currently 23 (12 words -> 24 bytes -> limit = 23), and
; (b) the gdt itself begins at whatever address the label gdt32beg has.
; This is nice, since it lets us move things around in memory.
align 16
GDTR32:                         ; global descriptor table
dw gdt32end - gdt32beg - 1      ; limit of GDT (size minus one)
dq gdt32beg                     ; linear address of GDT


; The global descriptor table itself
; ==================================
; The GDT table contains a number of entries called segment descriptors. 
; Each is 8 bytes long, and contains info about (a) the starting point 
; of the segment, (b) the length of the segment, and (c) the access 
; rights of the segment (this is for "protected" mode after all).
; Here's the layout of a single GDT entry:
;    limit_low:   2 bytes
;    base_low:    2 bytes
;    base_middle: 1 byte
;    access:      1 byte
;    granularity: 1 byte
;    base_high:   1 byte

; limit (2 bytes):  CPU generates a fault if we try to access past this
; base  (4 bytes):  This is just added to addresses in the given segment!
;                   The base is 32 bits, so we can access all of memory
;                   even if we just set the base of every descriptor to 0
;                   Ours are all 0, which means "OMG STFU SEGMENTATION!"
; access (1 byte):  
; granul (1 byte):  

; The limit, a 20 bit value, is the maximum addressable unit (either 
; in 1 byte units, or in pages). Hence, if you choose "page granularity,"
; i.e., if you set the granularity field to (4 KiB) and set the limit value to 0xFFFFF the segment will span the 
; full 4 GiB address space. 

; The "flags" nybl:
; =================
; 7  6  5  4
; Gr Sz 0  0
;
; Gr: Granularity bit. If this is 0, then the limit is in 1 byte 
; blocks (byte granularity). If this is 1, the limit is in 4 KiB blocks 
; (page granularity).
;
; Sz: Size bit. If 0 the selector defines 16 bit protected mode. If 1 it 
; defines 32 bit protected mode. You can have both 16 bit and 32 bit 
; selectors at once.
;
; This means that our flags nybl should be 0b1100, or 0xc

; The "access" byte:
; ==================
; |  7  |  6     5  |  4  |  3  |  2  |  1  |  0  |
; |  Pr |   Privl   |  1  |  Ex |  DC |  RW |  Ac |
;
; The bit fields are:
; -------------------
; Pr: Present bit. This must be 1 for all valid selectors.
; Privl: Privilege, 2 bits. Contains the ring level:
;     0 = highest (kernel), 3 = lowest (user applications)
; Ex: Executable bit. If this is 1, then code in this segment can be 
;     executed, and we've got a code selector (e.g., for cs). If this 
;     bit is 0, then we've got a data selector (e.g., for ds, ss, es)
; DC: Direction bit (data selectors) / Conforming bit (code selectors)
; [*] For data selectors: Tells the direction. If this is 0, then the 
; segment grows upward. If this is 1, then the segment grows downward, 
; so the offset has to be greater than the limit. This is presumably 
; where the whole "stack grows down in userspace, up in kernelspace" 
; thingy comes from :-)
; [*] For code selectors: If this is 1, then code in this segment can be 
; executed from *less privileged* levels. For example, code in ring 3
; (userland applications) can far-jump to "conforming" code in a ring 2 
; segment. The privl-bits represent the highest privilege level (i.e., 
; the *lowest* privilege number (which seems backwards at first)) that 
; is allowed to execute the segment. For example, code in ring 0 *cannot*
; far-jump to a conforming code segment with privl == 0x2, while code in 
; ring 2 and 3 can. Note that the privilege level remains the same, 
; i.e., a far-jump from ring 3 to a privl == 2 segment remains in ring 3 
; after the jump.
; If this is 0, then code in this segment can only be executed from the 
; ring set in privl.
; RW: Readable bit/Writable bit.
; [*] For code selectors, this is a "readable bit," and it determines 
; whether read access is allowed for this segment. Write access is never 
; allowed for code segments (Note to self: Not true? Can fuck with cr0!).
; [*] For data selectors, this is a "writable bit," and it determines 
; whether write access is allowed for this segment. Read access is 
; always allowed for data segments, or else they'd be pretty useless.
; Ac: Accessed bit. Just set this to 0. The CPU sets this to 1 when the 
; segment is accessed.

; Using the above info to build the access bytes for our selectors:
; =================================================================
; Code selector: 0b10011010 = 0x9a
; Data selector: 0b10010010 = 0x92

align 16
gdt32beg:
    ; Null descriptor (one of the blocks below, but all zeros)
    dq 0x0000000000000000

    ; Code segment descriptor
    dw 0xffff   ; limit low. Our limit = 0xfffff, (0xfffff+1)*4096 = 4GB
    dw 0x0000   ; base low
    db 0x00     ; base middle   
    db 0x9a     ; access byte (see above for why code gets 0x9a)
    db 0xc0|0x0f; low nybl: limit high. high nybl: flags (see above)
    db 0x00     ; base high

    ; Data segment descriptor
    dw 0xffff   ; limit low. Our limit = 0xfffff, (0xfffff+1)*4096 = 4GB
    dw 0x0000   ; base low
    db 0x00     ; base middle   
    db 0x92     ; access
    db 0xc0|0x0f; low nybl: limit high. high nybl: flags (see above)
    db 0x00     ; base high

    ; Save space for a TSS, which we'll probably need later.
    ; This slot isn't at all necessary now, but this reminds me to do it.
    dq 0x0000000000000000
gdt32end:
