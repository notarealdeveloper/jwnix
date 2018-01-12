; This is the entry point to the kernel.
; The bootloader uses BIOS calls to load the kernel image (not including
; itself) from disk into memory. This file is loaded starting at 0x10000.
; The bootloader then executes a far jump to 0x1000:0x0000, which jumps
; into this file's code.

%define SYSLOAD     0x8000
ORG     SYSLOAD

%define CURSOR     0xc000   ; Physical address where we store cursor word
%define CHARSIZE   2        ; VGA characters are 2 bytes
%define VGAWIDTH   80       ; Rows have 80 == 0xa0 slots
%define VGAHEIGHT  25       ; Cols have 25 == 0x19 slots
%define PAGESIZE   0x1000   ; The page size: 4092 (not yet used)

section .text
from_space:
    cli
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp
    mov ds,  ax
    mov es,  ax
    mov fs,  ax
    mov gs,  ax
    mov ss,  ax
    mov esp, SYSLOAD    ; stack <--(lower)-- SYSLOAD --(higher)--> code
    mov ebp, SYSLOAD    ; won't use this much, but it *should* be here

    call    stack_test

    mov     si, initmsg
    call    printmsg16
    call    cursor_init
    call    cursor_down


    ; Time for protected mode!
    ; ========================
    ; Note: Baremetal uses lgdt [cs:GDTR32], while linux 0.01
    ; uses lgdt [GDTR32] (or the equivalent, translating from 
    ; the as86 syntax Linus used in the linux 0.01 bootloader)
    ; Both work, and I'm fairly sure this isn't by accident, since
    ; our cs should *definitely* be zero, or else something fucked up.
    lgdt [GDTR32]               ; load global descriptor table register
    mov eax, cr0                ; grab control register zero
    or  eax, 0x01               ; set protected mode (PE) bit
    mov cr0, eax                ; ready... set...


    ; This will reload cs with the value 0x0008.
    ; Why 0x0008? Well, 
    jmp 0x0008:protectedmode    ; go!



    jmp die

stack_test:
    ; getting here changed the stack.
    ; undo that by popping ip into bx.
    ; then check that the stack grows down, 
    ; and behaves like we expect it to.
    pop bx
    cmp esp, SYSLOAD
    jne die
    push esp
    cmp esp, SYSLOAD-4
    jne die
    cmp dword [esp], SYSLOAD
    jne die
    pop esp
    cmp esp, SYSLOAD
    jne die
    cmp dword [esp-4], SYSLOAD
    jne die
    cmp esp, SYSLOAD
    jne die
    ; check that memory above esp is what we think it is
    mov eax, 0xc03166fa
    cmp eax, [SYSLOAD]
    jne die
    push bx ; restore old pushed ip
    ret

clear_screen:
    mov         ebx,    0xb8000
    .clearslot:
    cmp         ebx,    0xb8000 + (CHARSIZE)*(VGAWIDTH*VGAHEIGHT)
    jge         .done
    ; Even empty cells need grey foreground so we can always see the 
    ; cursor, even if it has been moved over an empty cell. Hence 0x0700
    ; i.e., Black bg (0x0), grey fg (0x7), nul byte (0x00)
    mov word    [ebx],  0x0700
    add         ebx,    2
    jmp         .clearslot
    .done:      ret


cursor_init:
    mov  [CURSOR], word 0x0000       ; our cursor address
    call redraw_cursor
    ret

cursor_down:
    add [CURSOR], word VGAWIDTH
    call redraw_cursor
    ret

cursor_right:
    inc word [CURSOR]
    call redraw_cursor
    ret

redraw_cursor:
    push ax
    push dx
    mov al, 0x0f
    mov dx, 0x3d4
    out dx, al

    mov al, byte [CURSOR]
    mov dx, 0x3d5
    out dx, al

    mov al, 0x0e
    mov dx, 0x3d4
    out dx, al

    mov al, byte [CURSOR+1]
    mov dx, 0x3d5
    out dx, al

    pop dx
    pop ax
    ret

die:
    hlt
    jmp die


printmsg16:
    ; put string address in si beforehand
    pusha               ; push all general purpose registers
    mov ebx, 0xb80a0    ; base address of vga memory map + 1 line
    mov ax,  0x0300     ; ah determines the fg and bg color
    .getchar:           ; this is our loop label
    lodsb               ; Load byte at address ds:(e)si into al
    cmp al,     0x00    ; If the byte is 0,
    je .done            ; then we're done
    mov word [ebx], ax  ; otherwise, write the vga entry (fg4,bg4,byte8)
    add ebx, 0x02       ; pointer++, since ebx is a (short *)
    jmp .getchar        ; get the next character
    .done:
    popa                ; pop all general purpose registers
    ret


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

initmsg: db "Entered stage two...", 0x00

; ====================== ;
; !!! PROTECTED MODE !!! ;
; ====================== ;

USE32
protectedmode:
    ; Welcome to protected mode! Now you're a man.
    ; ============================================
    ; First, we set all the segment registers that have anything to do
    ; with "data" (i.e., all of them except cs) to the same 4GB data 
    ; descriptor. To see what's going on here, we have to understand the 
    ; different meaning that segment registers have in protected mode, 
    ; (as opposed to the "simpler" meaning they have in protected mode)
    ; This difference is explained very well (twice, no less) at
    ; http://geezer.osdevbrasil.net/johnfine/segments.htm
    ; Here's what whatshisface calls the "simple but wrong version"
    ; (though it's true enough to help us understand the right version).
    ; In protected mode the CPU doesn't do the "one nybble shift left"
    ; business to segment registers in order to get a physical address.
    ; In protected mode, the value in a segment register isn't even a 
    ; segment number! It's something called a "selector". Bit 2 of the 
    ; selector tells the CPU whether to use the GDT or LDT. Bits 3 to 15 
    ; of the selector index to one of the descriptors in the GDT or IDT.
    ; Now, we all know that most memory accesses (in all modes) 
    ; implicitly or explicitly use some segment register (ds/es/ss/etc).
    ; So, when we try to execute an instruction in protected mode,
    ; like "mov byte [0x9000], al" the CPU gets the address we actually 
    ; asked for (in this case, 0x9000) and adds it to the "base" value 
    ; from the descriptor to obtain a 32-bit "linear" address
    ; (Aside: what is "the descriptor" in the above sentence?
    ; presumably, "the descriptor" is the descriptor we registered
    ; *for that segment.* Example: below, we put 16 in all the data
    ; segment registers, which essentially associates all those segment
    ; registers with whatever descriptor is found 16 bytes into the
    ; global descriptor table; for us, it's the "data segment descriptor"
    ; that comes 3rd in our gdt, which is 16 bytes after gdt32beg above.)
    ; Okay, where were we? Each descriptor also contains a "limit"
    ; (length minus one) for all segments we choose to associate with
    ; that descriptor. Unlike in real mode, the CPU will generate a 
    ; fault if we attempt to access beyond the limit of a segment.
    ; Bits 0 and 1 of the selector are known as the "RPL". The current 
    ; priviledge level is known as the "CPL". Those values are checked 
    ; against the descriptor priviledge "DPL" to see if the access 
    ; should be permitted.

    ; Note the value below (16) is determined as follows:
    ; Bits 0 and 1: The "RPL" or "Requested privilege level" = 0 (kernel)
    ; Bit 2 tells the CPU whether to use the GDT or LDT (0 for GDT)
    ; Bits 3:16 (should this be 3:32?) point to an entry in the GDT.
    ; Our value below is 16 because the first 3 bits are 0, and our data
    ; selector is located at index 0b0010 = 2 into the GDT.
    mov eax, 0b00000000000000000000000000010000 ; 16
    mov ds, eax
    mov es, eax
    mov fs, eax
    mov gs, eax
    mov ss, eax
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp
    mov esp, 0x8000         ; Set a known free location for the stack

    ; Write "32!" into VGA memory so we know we're in protected mode.
    mov [0xb8000+(2*0xa0)-(2*3)], byte "3"
    mov [0xb8000+(2*0xa0)-(2*2)], byte "2"
    mov [0xb8000+(2*0xa0)-(2*1)], byte "!"

    ; Now that you're here, you should relax and enjoy this article, 
    ; since it's almost certainly something you've encountered by now :)
    ; http://en.wikipedia.org/wiki/Triple_fault

    jmp halt

halt:
    hlt
    jmp halt
