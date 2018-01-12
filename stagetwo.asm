; This is the entry point to the kernel.
; The bootloader uses BIOS calls to load the kernel image (not including
; itself) from disk into memory. This file is loaded starting at 0x10000.
; The bootloader then executes a far jump to 0x1000:0x0000, which jumps
; into this file's code.

%define SYSLOAD     0x8000
ORG     SYSLOAD

section .text
; ====================== ;
; !!! PROTECTED MODE !!! ;
; ====================== ;


USE32
global _start
_start:
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
    cli
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp

    ; Set the data segment registers to use their proper GDT entry
    ; 0b10000. Ignore low 3 bits to get 2, i.e., GDT[2]
    mov eax, 16
    mov ds, eax
    mov es, eax
    mov fs, eax
    mov gs, eax
    mov ss, eax
    mov esp, 0x8000         ; Set a known free location for the stack

    ; Make sure we're really in protected mode
    mov eax, cr0
    and eax, 0x1
    cmp eax, 0x1
    jne halt

    call    cursor_init                     ; set up the cursor
    call    cursor_down                     ; move it down one row

    mov     ax,  0x0300         ; ah determines the fg and bg color
    mov     esi, protmsg        ; the message to print
    mov     edi, 0xb8000+0xa0   ; base address of vga memory map + 1 line
    call    printmsg

    ; Write "32!" into VGA memory, for fun
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

%include "cursor.asm"
printmsg:
    ; put string address in si beforehand
    pusha               ; push all general purpose registers
    .getchar:           ; this is our loop label
    lodsb               ; Load byte at address ds:(e)si into al
    cmp al,     0x00    ; If the byte is 0,
    je .done            ; then we're done
    mov word [edi], ax  ; otherwise, write the vga entry (fg4,bg4,byte8)
    add edi, 0x02       ; pointer++, since ebx is a (short *)
    call cursor_right   ; move the cursor right
    jmp .getchar        ; get the next character
    .done:
    popa                ; pop all general purpose registers
    ret

section .data
protmsg: db "Entered protected mode!", 0x00

