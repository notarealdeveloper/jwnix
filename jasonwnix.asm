ORG     0
BITS    16

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


; Should be a macro to prevent segment fuckery.
%macro clear_all_registers 0
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor esp, esp
    xor ebp, ebp
    mov ds,  ax
    mov es,  ax
    mov ss,  ax
    mov fs,  ax
    mov gs,  ax
%endmacro


%define INIT        0x7c00  ; where the bios loads our code
%define PAGESIZE    0x1000  ; The page size: 4092



align 16
start:
    clear_all_registers
    mov sp, 0x7c00 + 0x1000 + 0x200         ; set up the stack segment
    cli                                     ; disable hardware interrupts
    call    clear_screen
    call    print_init_msg

    ; Print an init message
    ; mov dword       [0x69*4],   INIT + handler
    ; int 0x69        ; Interrupt 0x69


    ; Now we want to load stage two at 0x10000

    ; We'll use Logical Block Addressing, although we got CHS working too
    ; Reading sectors from the disk using Logical Block Addressing
    ; Reading 16 sectors from LBA 1 to physical address 0x10000
    mov bx, 0x0000      ; our data segment
    mov ds, bx
    mov si, INIT+DAP    ; address of "disk address packet"
    mov ah, 0x42        ; ah = BIOS call number for this int 0x13 call
    mov dl, 0x80        ; dl = "drive number." Typically 0x80
    int 0x13

    jmp 0x1000:0x0000

    jmp die

DAP:
        db    0x10      ; size of this disk address packet (16)
        db    0         ; always zero
sectrs: dw    16        ; number of sectors (blocks) to copy (1 works)
dstloc: dw    0x0000    ; where to copy the data (offset)
        dw    0x1000    ; where to copy the data (segment)
srcloc: dd    1         ; starting LBA (starts at 0, so do 1. 0 flashes!)
        dd    0         ; used for upper part of 48 bit LBAs

    jmp die


align 16
handler:
    mov ebx, 0xb8000
    mov ax, 0x0200+"O"
    mov word [ebx+0], ax
    mov ax, 0x0200+"N"
    mov word [ebx+2], ax
    mov ax, 0x0200+"E"
    mov word [ebx+4], ax
    iret

print_init_msg:
    push eax
    push ebx

    mov ebx, 0xb8000    ; base address of vga memory map
    mov ax,  0x0200     ; ah determines the fg and bg color

    mov si, INIT+initmsg    ; Put starting address in di

    .getchar:
    lodsb                   ; Load byte at address ds:(e)si into al
    cmp al,     0x00        ; If the byte is 0,
    je .done
    mov word [ebx], ax
    add ebx, 0x02
    jmp .getchar
    .done:
    pop ebx
    pop eax
    ret

initmsg: db "JasonWnix is booting...", 0x00

align 16
invalid_opcode:
    ; push word bx
    mov word [ebx], 0x0300 + "W"
    add ebx, 2
    mov word [ebx], 0x0300 + "X"
    add ebx, 2
    mov word [ebx], 0x0300 + "Y"
    add ebx, 2
    mov word [ebx], 0x0300 + "Z"
    add ebx, 2
    ; pop word bx
    pop  dx         ; pop ip off the stack, into dx
    add  dx, 2      ; ip += 2
    push dx         ; put ip back where iret expects it to be
    iret            ; leap of confidence!


clear_screen:
    mov         ebx,    0xb8000
    .clearslot:
    cmp         ebx,    0xb8000 + (2)*(80*25)
    jge         .done
    ; Even empty cells need grey foreground so we can always see the 
    ; cursor, even if it has been moved over an empty cell. Hence 0x0700
    ; i.e., Black bg (0x0), grey fg (0x7), nul byte (0x00)
    mov word    [ebx],  0x0700
    add         ebx,    2
    jmp         .clearslot
    .done:      ret


die:
    nop
    jmp die





times 510-($-$$) db 0x00 ; pad remainder of boot sector with zeros
dw 0xAA55                ; the standard pc boot signature

