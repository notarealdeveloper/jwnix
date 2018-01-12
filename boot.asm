; The bios loads our code at 0x7c00. We then:
; (a) print an init message to the screen, 
; (b) check that hardware and software interrupts work (for fun),
; (c) load the next stage at the memory address defined by SYSLOAD,
; (d) 

ORG     0x7c00              ; This makes life *so* much easier!!!
BITS    16

; Note: If you modify this, remember to modify it in stage two as well.
%define SYSLOAD 0x8000      ; where we'll load the rest of the system

align 16
start:
    ; Note: cs *is* zero when we begin.
    ; I didn't think this was true at first, 
    ; due to some understandable quirks with nasm.
    mov eax, cs
    cmp eax, 0
    jne die
    ; If cs is ever *not* zero, we can clear it 
    ; in several ways, my favorite of which is:
    ; jmp 0x0000:clearcs
    ; clearcs:

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
    mov fs,  ax
    mov gs,  ax
    mov ss,  ax

	mov     sp, 0x7c00                      ; set up the stack segment
    call    clear_screen                    ; kill bios boot messages

    mov     si, initmsg                     ; move initmsg into si
    call    printmsg16                      ; and print it.


    ; If "OK" appears on the far right, then interrupts work.
    mov dword       [0x06*4],   invalid_opcode_handler
    mov dword       [0x09*4],   keyboard_interrupt_handler
    mov dword       [0x69*4],   software_interrupt_handler
    sti             ; Tell cpu to accept interrupts from peripherals
    int 0x69        ; Test interrupt 0x69 (software interrupt)
    ud2             ; Generate an invalid opcode (hardware interrupt)
    int 0x09        ; Generate a keyboard interrupt (real ones work too)
    cli             ; No hardware interrupts. Soft & NMI ones still work

    ; Now we want to load stage two at SYSLOAD 
    ; ========================================
    mov si, DAP         ; address of "disk address packet"
    mov ah, 0x42        ; ah = BIOS call number for this int 0x13 call
    mov dl, 0x80        ; dl = "drive number." Typically 0x80
    int 0x13

    ; Check that the loading went as expected
    ; Other magic we can use:
    ; cmp eax, 0xdeadbeef   ; to use this magic, do jmp 0x0000:SYSLOAD+4
    ; cmp eax, 0x90909090   ; safe, but nasm often makes nop sleds...
    ; =======================================
    cmp dword [SYSLOAD], 0xc03166fa
    jne loading_is_fucked

    jmp overthefuckfest

    ; ===========================================
    ; Here's how we'll go to protected mode, 
    ; once we've properly set-up the gdt and idt.
    ; Remember: Look at linux 0.01 and baremetal
    ; ===========================================
    lidt    [idt48]     ; set the idt
    lgdt    [gdt48]     ; set the gdt
    mov     eax, cr0    ; grab control register zero
    or      eax, 0x01   ; set the "protected mode enable" bit
    mov     cr0, eax    ; here we go!


    overthefuckfest:
    jmp 0x0000:SYSLOAD  ; currently SYSLOAD is 0x8000.


DAP:
        db    0x10      ; size of this disk address packet (16)
        db    0         ; always zero
sectrs: dw    16        ; number of sectors (blocks) to copy (1 works)
dstloc: dw    SYSLOAD   ; where to copy the data (offset)
        dw    0x0000    ; where to copy the data (segment) (was 0x1000)
srcloc: dd    2         ; starting LBA (starts at 0, so do 1. 0 flashes!)
        dd    0         ; used for upper part of 48 bit LBAs


software_interrupt_handler:
    mov ebx, 0xb8000 + 0xa0 - (2*3)
    mov dword [ebx], (0x0700+"O")
    iret

loading_is_fucked:
    mov si, loadfail
    call printmsg16
    jmp $

printmsg16:
    ; put string address in si beforehand
    pusha               ; push all general purpose registers
    mov ebx, 0xb8000    ; ebx contains base address of vga memory map
    mov ax,  0x0200     ; ah determines the fg and bg color
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

initmsg:    db "JasonWnix is booting...", 0x00
loadfail:   db "Your magic fucked up...", 0x00

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
    mov word    [ebx],  0x0700  ; white fg & black bg
    add         ebx,    2
    jmp         .clearslot
    .done:      ret


die:
    hlt
    jmp die


idt48:
    dw    0x0000          ; idt limit = 0x0000
    dw    0x0000, 0x0000  ; idt base  = 0x0000:0x0000

gdt:
    dw    0,0,0,0       ; dummy
    dw    0x07FF        ; 8Mb - limit = 2047 (2048*4096 = 8Mb)
    dw    0x0000        ; base address = 0
    dw    0x9A00        ; code read/exec
    dw    0x00C0        ; granularity = 4096, 386

    dw    0x07FF        ; 8Mb - limit = 2047 (2048*4096 = 8Mb)
    dw    0x0000        ; base address = 0
    dw    0x9200        ; data read/write
    dw    0x00C0        ; granularity = 4096, 386


gdt48:
    dw    0x0800        ; gdt limit = 2048, 256 GDT entries
    dw    gdt, 0x0009   ; gdt base  = 0x9nnn


times 510-($-$$) db 0x00 ; pad remainder of boot sector with zeros
dw 0xAA55                ; the standard pc boot signature
times 512 db 0x00
;times 1024 db 0x00
