; This is the entry point to the kernel.
; The bootloader uses BIOS calls to load the kernel image (not including
; itself) from disk into memory. This file is loaded starting at 0x10000.
; The bootloader then executes a far jump to 0x1000:0x0000, which jumps
; into this file's code.

%define CURSOR     0xc000   ; Physical address where we store cursor word
%define CHARSIZE   2        ; VGA characters are 2 bytes
%define VGAWIDTH   80       ; Rows have 80 == 0xa0 slots
%define VGAHEIGHT  25       ; Cols have 25 == 0x19 slots
%define PAGESIZE   0x1000   ; The page size: 4092 (not yet used)


section .text
global _start
_start:
from_space:
    call    cursor_init
    call    print_init_msg
    call    cursor_init
    call    cursor_down

    jmp die

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
    nop
    jmp die


print_init_msg:
    push eax
    push ebx

    mov ebx, 0xb80a0    ; base address of vga memory map + down one line
    mov ax,  0x0300     ; ah determines the fg and bg color

    mov esi,  initmsg   ; Put starting address in si

    .getchar:
    lodsb               ; Load byte at address ds:(e)si into al
    cmp al,     0x00    ; If the byte is 0,
    je .done
    mov word [ebx], ax
    add ebx, 0x02
    jmp .getchar
    .done:

    pop ebx
    pop eax
    ret

; According to hexdump, this is placed at the bottom anyway, 
; below the text section, even if we put it at the top.
section .data
initmsg: db "Entered stage two...", 0x00
