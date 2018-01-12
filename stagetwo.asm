; This is the entry point to the kernel.
; The bootloader uses BIOS calls to load the kernel image (not including
; itself) from disk into memory. This file is loaded starting at 0x10000.
; The bootloader then executes a far jump to 0x1000:0x0000, which jumps
; into this file's code.

%define CURSOR     0xc000   ; Physical address where we store cursor word
%define CHARSIZE   2        ; VGA characters are 2 bytes
%define VGAWIDTH   80       ; Rows have 80 == 0xa0 slots
%define VGAHEIGHT  25       ; Cols have 25 == 0x19 slots


from_space:
    ;call    clear_screen
    ;call    print_init_msg
    call    cursor_init

    call    cursor_down
    mov ebx, 0xb8000+0xa0

    mov word [ebx], 0x0600 + "T"
    add ebx, 2
    call    cursor_right

    mov word [ebx], 0x0600 + "W"
    add ebx, 2
    call    cursor_right

    mov word [ebx], 0x0600 + "O"
    add ebx, 2
    call    cursor_right

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
    ret

die:
    nop
    jmp die


print_init_msg:
    push eax
    push ebx
    mov ebx, 0xb80a0    ; base address of vga memory map
    mov ax,  0x0200     ; ah determines the color

    xor esi,esi
    mov si, 0x7c00+initmsg    ; Put starting address in di

    .getchar:
    lodsb                   ; Load byte at address ds:(e)si into al
    cmp al,     0x00        ; If the byte is 0,
    je .done
    mov ah, 0x02
    mov word [ebx], ax
    add ebx, 0x02
    jmp .getchar
    .done:
    pop ebx
    pop eax
    ret

initmsg: db "Entered stage two...", 0x00


; Write a VGA entry
; =================
; mov ax, 0x0200+"X" ; Format of VGA entry is bg-nybl, fg-nybl, char
; mov bx, 0xb000
; mov gs, bx
; mov word [gs:0x8000], ax
