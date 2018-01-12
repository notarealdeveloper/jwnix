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


align 16
start:
    clear_all_registers
    cli                                 ; disable hardware interrupts
    mov sp, 0x7c00 + 0x1000 + 0x200     ; set up the stack segment

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

    ;ud2            ; Generate invalid opcode, to test exception handler!
    db 0x0f, 0x0b   ; An actual invalid opcode

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
    mov word [gs:0x8500 + 0xa0*0], ax
    inc al
    mov word [gs:0x8502 + 0xa0*1], ax
    inc al
    mov word [gs:0x8504 + 0xa0*2], ax
    inc al
    mov word [gs:0x8506 + 0xa0*1], ax
    inc al
    pop gs
    pop bx
    pop ax
    iret

invalid_opcode:
    mov ax, 0x0300+"W" ; Format of VGA entry is bg-nybl, fg-nybl, char
    mov bx, 0xb000
    mov gs, bx
    mov word [gs:0x85a8], ax
    inc al
    mov word [gs:0x85aa], ax
    inc al
    mov word [gs:0x85ac], ax
    inc al
    mov word [gs:0x85ae], ax
    inc al
    xor cx, cx
    iret

interrupt_msg:  db "Haha gotcha bitch! ", 0x0d, 0x0a, 0x00

die:
    nop
    jmp die

;initmsg:    db "Welcome to JasonWnix!", 0x0d, 0x0a, 0x00

times 510-($-$$) db 0x00 ; pad remainder of boot sector with zeros
dw 0xAA55                ; the standard pc boot signature;

