ORG     0x7c00              ; This makes life *so* much easier!!!
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
    call    clear_screen                    ; kill bios boot messages
    call    print_init_msg                  ; print an init message


    ; If "OK" appears on the far right, then interrupts work.
    mov dword       [0x06*4],   invalid_opcode_handler
    mov dword       [0x09*4],   keyboard_interrupt_handler
    mov dword       [0x69*4],   software_interrupt_handler
    int 0x69        ; Test interrupt 0x69 (software interrupt)
    ud2             ; Generate an invalid opcode (hardware interrupt)
    ;int 0x09

    ; Now we want to load stage two at 0x10000
    ; ========================================
    mov si, DAP         ; address of "disk address packet"
    mov ah, 0x42        ; ah = BIOS call number for this int 0x13 call
    mov dl, 0x80        ; dl = "drive number." Typically 0x80
    int 0x13


    jmp 0x0000:0x0000   ; formerly 0x1000:0x0000

    jmp die

DAP:
        db    0x10      ; size of this disk address packet (16)
        db    0         ; always zero
sectrs: dw    16        ; number of sectors (blocks) to copy (1 works)
dstloc: dw    0x0000    ; where to copy the data (offset)
        dw    0x0000    ; where to copy the data (segment) (was 0x1000)
srcloc: dd    1         ; starting LBA (starts at 0, so do 1. 0 flashes!)
        dd    0         ; used for upper part of 48 bit LBAs



software_interrupt_handler:
    mov ebx, 0xb8000 + 0xa0 - (2*3)
    mov dword [ebx], (0x0700+"O")
    iret


print_init_msg:
    push eax
    push ebx
    mov ebx, 0xb8000    ; base address of vga memory map
    mov ax,  0x0200     ; ah determines the fg and bg color
    mov si,  initmsg    ; Put starting address in di
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


invalid_opcode_handler:
    push ebx
    mov  ebx, 0xb8000 + 0xa0 - (2*2)
    mov  word [ebx], 0x0700 + "K"
    pop  ebx
    pop  dx         ; pop ip off the stack, into dx
    add  dx, 2      ; ip += 2
    push dx         ; put ip back where iret expects it to be
    iret            ; leap of confidence!

keyboard_interrupt_handler:
    push ebx
    mov  ebx, 0xb8000 + 0xa0 - (2)
    mov  word [ebx], 0x0700 + "!"
    pop  ebx
    iret


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


;gdt:
;    dw    0,0,0,0       ; dummy
;    dw    0x07FF        ; 8Mb - limit = 2047 (2048*4096 = 8Mb)
;    dw    0x0000        ; base address = 0
;    dw    0x9A00        ; code read/exec
;    dw    0x00C0        ; granularity = 4096, 386
;
;    dw    0x07FF        ; 8Mb - limit = 2047 (2048*4096 = 8Mb)
;    dw    0x0000        ; base address = 0
;    dw    0x9200        ; data read/write
;    dw    0x00C0        ; granularity = 4096, 386
;
;
;gdt_48:
;    dw    0x800         ; gdt limit = 2048, 256 GDT entries
;    dw    gdt, 0x9      ; gdt base  = 0X9xxxx
