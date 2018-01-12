; SETTING UP 4K OF STACK SPACE AFTER THIS BOOTLOADER
; From http://en.wikipedia.org/wiki/X86_memory_segmentation
; "In both real and protected modes the system uses 16-bit segment 
; registers to derive the actual memory address. In real mode the 
; registers CS, DS, SS, and ES point to the currently used program 
; code segment (CS), the current data segment (DS), the current stack
; segment (SS), and one extra segment chosen by the programmer (ES)."

; From http://wiki.osdev.org/Boot_Sequence
; A device is "bootable" if it carries a boot sector with the byte 
; sequence 0x55, 0xAA in bytes 511 and 512 respectively. When the 
; BIOS finds such a boot sector, it is loaded into memory at a 
; specific location; this is usually 0x0000:0x7c00 (segment 0, 
; address 0x7c00). However, some BIOSes load to 0x7c0:0x0000 
; (segment 0x07c0, offset 0), which resolves to the same physical 
; address, but can be surprising.

BITS 16
%define CODESTART   0x7c00  ; where the bios loads our code
%define PAGESIZE    0x1000  ; The page size: 4092
%define MBRSIZE     0x0200  ; The size of our boot sector: 512
%define IDT         0x5000

%macro print 1
    push    eax
    mov si, %1              ; put string position into si
    mov     ah, 0x0e
    %%repeat:
    lodsb                   ; get character from string
    cmp al, 0               ; if it's zero,
    je  %%done              ; then we're done
    int 0x10                ; otherwise, make the bios print it
    jmp %%repeat
    %%done:
    pop eax
%endmacro

%macro print_digit 1
    push    ax
    push    cx
    mov     al, %1
    add     al, 0x30
    mov     ah, 0x0e
    int     0x10
    pop     cx
    pop     ax
%endmacro

%macro print_byte 1
    push    ax
    push    cx
    mov     al, %1
    mov     ah, 0x0e
    int     0x10
    pop     cx
    pop     ax
%endmacro

%macro reg_eq_strlen 2
    ; Usage: reg_eq_strlen reg, str
    ; Computing the length of a nul-terminated string using repne scasb
    ; Inputs: rdi = string address, al = byte to search for
    ; Output: rcx = length of the string in rdi
    ; Clobbered: reg, rcx
    push    ax
    push    di
    mov     di, %2      ; Put starting address in di
    mov     al,  0x00   ; Put byte to search for in al
    mov     cx, -1      ; Start count at 0xffff
    cld                 ; Clear direction flag (increment di each time)
    repne   scasb       ; Scan string for NUL, doing --cx for each char
    add     cx, 2       ; cx will be -2 for length 0, -3 for length 1...
    neg     cx          ; cx is now -(strlen), so negate it.
    pop     di
    pop     ax
    mov     %1, cx
%endmacro

%macro clear_all_registers 0
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
%endmacro

; Note: cs cannot be changed directly
start:
    ;clear_all_registers
    cli                                 ; disable hardware interrupts
    mov sp, 0x7c00 + 0x1000 + 0x200     ; set up the stack segment
    ;mov ax, 0x07c0                     ; set up the data segment

    mov ax, 0x00
    mov ds, ax

    mov     ah, 0x0e
    mov     al, "A"
    int 0x10

    mov dword    [0x80*4],   0x2000

    ; Clear cx
    mov byte    [0x2000],   0x66
    mov byte    [0x2001],   0x31
    mov byte    [0x2002],   0xc9
    mov byte    [0x2003],   0xcf

    mov     ah, 0x0e
    mov     al, "B"
    int 0x10

    mov cx, 0x69
    cmp cx, 0x69
    jne die
    mov dx, 0x69
    cmp dx, 0x69
    jne die

    int 0x80

    cmp cl, 0x00
    jne die
    cmp dl, 0x69
    jne die

    mov     ah, 0x0e
    mov     al, "C"
    int 0x10

    ; Changing the location of the interrupt handler
    ; I finally understand all of the insanity (or at least most of it)
    ; Changing the 0x5000 on the following line to 0x5004 gets us only
    ; ABC, since we're jumping past the code, while changing it to 
    ; 0x4ffc gets us all the way to ABCD. However, changing it to
    ; 0x4fff only gets us ABC, presumably because of a bus error.
    ; (Edit: It's more likely due to the 0x66 byte mentioned below.)
    ; Most even numbers in the stretch before 0x5000 get us to ABCD,
    ; since we just carry on executing into the function.
    ; However, no even or odd numbers after 0x5000 get us there, except
    ; for 0x5001, presumably because the lack of a 0x66 clears dl anyway
    ; (I forget which, but I think one clears dx and one clears dl)
    mov dword   [0x80*4],   0x5000
    ; Code to clear dx
    mov byte    [0x5000],   0x66
    mov byte    [0x5001],   0x31
    mov byte    [0x5002],   0xd2
    mov byte    [0x5003],   0xcf


    mov cl, 0x88
    cmp cl, 0x88
    jne die
    mov dl, 0x88
    cmp dl, 0x88
    jne die

    ; Note: This next line is the ultimate proof that our interrupt
    ; is actually doing something. This jumps into where we began,
    ; which leads (as expected!) to an infinite loop of ABCs.
    ; Uncomment this line for some satisfying chaos :-)
    ; Even better: while 0x7c00 gives infinite ABCs, 0x7c10 gives BCs
    ; and 0x7c30 gives Cs. This is exactly what we should expect!
    ; mov dword   [0x80*4],   0x7c00
    int 0x80

    cmp cl, 0x88
    jne die
    cmp dl, 0x00
    jne die

    ; print "D"
    ; If we get here, we won!
    resb 100
    mov     ah, 0x0e
    mov     al, "D"
    int 0x10

    jmp die


interrupt_msg:  db "Haha gotcha bitch! ", 0x0d, 0x0a, 0x00

int_handler:
    xor dx, dx
    iret

die:
    jmp $


initmsg:    db "Welcome to JasonWnix!", 0x0d, 0x0a, 0x00

times 510-($-$$) db 0x00 ; pad remainder of boot sector with zeros
dw 0xAA55                ; the standard pc boot signature;

