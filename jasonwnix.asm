ORG     0           ; Not needed
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



; IMPORTANT!
; ==========
; We can do long calls as follows
; call 0x07c0:ihandler
; or long jumps like this
; jmp 0x07c0:ihandler
; We can also do both like this
; push cs ; (or other segment register)
; push bx ; (or other general register)
; retf

; Write a VGA entry
; =================
; mov ax, 0x0200+"X" ; Format of VGA entry is bg-nybl, fg-nybl, char
; mov bx, 0xb000
; mov gs, bx
; mov word [gs:0x8000], ax


%define INIT        0x7c00  ; where the bios loads our code
%define PAGESIZE    0x1000  ; The page size: 4092
%define MBRSIZE     0x0200  ; The size of our boot sector: 512
%define IDT         0x5000

%define CHARSIZE   2        ; VGA characters are 2 bytes
%define VGAWIDTH   80       ; Rows have 80 == 0xa0 slots
%define VGAHEIGHT  25       ; Cols have 25 == 0x19 slots
%define CURSOR     0xc000   ; Physical address where we store our cursor word


align 16
start:
    cli                                 ; disable hardware interrupts
    mov sp, 0x7c00 + 0x1000 + 0x200     ; set up the stack segment

    clear_all_registers
    call    clear_screen
    call    cursor_init


	;mov ax, 0x07C0		    ; 0x7C00 is where the BIOS loads our code
	;add ax, 288		    ; 288 = (4096 + 512) / 16 bytes per paragraph
	;mov ss, ax             ; ss = 0x07C0 + 288 = 2272
	;mov sp, 4096           ; stack pointer = address number 4096

	;mov ax, 0x07C0		    ; Set data segment to where we're loaded
	;mov ds, ax
	;mov es, ax


    mov dword    [0x69*4],   INIT+handler
    mov dword    [0x06*4],   INIT+invalid_opcode

    int 0x69        ; Interrupt 0x69:
    int 0x69        ; Interrupt 0x69:

    sti
    mov ebx, 0xb80a0
    ud2             ; Generate invalid opcode, to test our exception handler
    db 0x0f, 0x0b   ; An actual invalid opcode

    call sector2
    call cursor_right
    call cursor_right
    call cursor_right
    call cursor_right
    call cursor_down
    call cursor_down
    ;call cursor_right

    jmp die

; Note: add 0xa0 to get to the next row
align 16
handler:
    push ax
    push bx
    push gs
    mov ax, 0x0200+"E" ; Format of VGA entry is bg-nybl, fg-nybl, char
    mov bx, 0xb000
    mov gs, bx
    mov word [gs:0x8000], ax
    inc al
    mov word [gs:0x8002], ax
    inc al
    mov word [gs:0x8004], ax
    inc al
    mov word [gs:0x8006], ax
    inc al
    pop gs
    pop bx
    pop ax
    iret

align 16
invalid_opcode:
    ; Note: Once we're in an invalid opcode exception handler, 
    ; the saved instruction pointer points to the instruction that caused the 
    ; exception. Therefore, if we just iret in the standard manner, we'll jump
    ; *back* to the invalid opcode, and thus back into this exception handler.
    ; This won't be clear unless our debug statements access shared state, so 
    ; that they write to a different location in VGA memory each time they run. 
    ; Without this (usually undesirable) property of accessing shared mutable 
    ; state,  we won't notice that we're in an infinite loop of calling the 
    ; invalid_opcode  handler, since we'll just keep writing to the same 
    ; locations in VGA memory. Remove this when you're done debugging.

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
    ; We're now ready to return, but our instruction pointer is still pointing
    ; to the invalid opcode. This is where the x86's variable length opcodes
    ; really make things difficult, at least if we want to *ignore* the 
    ; exception and keep going. Since I just want to test this handler, 
    ; rather than provide a general recovery mechanism for invalid opcodes
    ; (which is probably a horrible idea anyway) we'll just do ip += 2 and keep 
    ; moving, since the only invalid opcodes we're *purposely* raising are two 
    ; bytes long.
    pop  dx         ; pop ip off the stack, into dx
    add  dx, 2      ; ip += 2
    push dx         ; put ip back where iret expects it to be
    iret            ; leap of confidence!



die:
    nop
    jmp die

;initmsg:    db "Welcome to JasonWnix!", 0x0d, 0x0a, 0x00


times 510-($-$$) db 0x00 ; pad remainder of boot sector with zeros
dw 0xAA55                ; the standard pc boot signature;

; Here begins the 2nd sector of the drive!
sector2:
    mov ax, 0x0400+"J" ; Format of VGA entry is bg-nybl, fg-nybl, char
    mov bx, 0xb000
    mov gs, bx
    mov word [gs:0x8140], ax
    inc al
    mov word [gs:0x8142], ax
    inc al
    mov word [gs:0x8144], ax
    inc al
    mov word [gs:0x8146], ax
    inc al
    xor cx, cx
    ret

clear_screen:
    mov         ebx,    0xb8000
    .clearslot:
    cmp         ebx,    0xb8000 + (CHARSIZE)*(VGAWIDTH*VGAHEIGHT)
    jge         .done
    ; Even empty cells need light grey foreground so we can always see the
    ; cursor, even if it has been moved over an empty cell. Hence: use 0x0700
    mov word    [ebx],  0x0700
    add         ebx,    2
    jmp         .clearslot
    .done:      ret



; Works only for 80x25 text mode. Can be generalized.
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

get_cursor_pos:
    ; cursor position is returned in ah
    ;push bx
    mov     ah,  0x03    ; read cursor pos
    ;xor     bh,  bh
    int     0x10         ; use the BIOS, just this time.
    ;pop bx
    ret

; BIOS DATA AREA: 0x00000400 - 0x000004ff (256 bytes)
; ===================================================
; Below, we note several places in the BIOS data area where information
; about the hardware is stored. Using these locations to get the relevant
; information will make our code more portable than the current strategy,
; in which we just use the correct IO ports and memory locations directly.
; So why not do this everywhere in the code now? Well, I'm trying not to even 
; use the  BIOS (i.e., no BIOS calls in my code, after the BIOS loads us) so
; while the BDA strategy may give us more portability, it also involves using
; code written by others, which is exactly what I'm trying to avoid, in order
; to achieve maximum learnin's :-D

; VGA base IO port: RAM 0x0463.
; Qemu: [0x0463] = 0x3d4
; This port number is needed for getting and setting the cursor position. 
; We just assume it's 0x3d4, and that works. 

; VGAWIDTH: RAM 0x044A
; Qemu: [0x044A] = 80
; This lets us replace the long cmp line in clear_screen with
; mov         dx,     [0x044A]
; imul        dx,     VGAHEIGHT
; imul        dx,     CHARSIZE
; add         edx,    0xb8000
