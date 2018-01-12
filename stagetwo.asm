; This is the entry point to the kernel.
; The bootloader uses BIOS calls to load the kernel image (not including
; itself) from disk into memory. This file is loaded starting at 0x10000.
; The bootloader then executes a far jump to 0x1000:0x0000, which jumps
; into this file's code.

from_space:
    mov ebx, 0xb8140
    mov word [ebx], 0x0600 + "H"
    add ebx, 2
    mov word [ebx], 0x0600 + "A"
    add ebx, 2
    mov word [ebx], 0x0600 + "H"
    add ebx, 2
    mov word [ebx], 0x0600 + "A"
    add ebx, 2
    jmp die

die:
    nop
    jmp die
