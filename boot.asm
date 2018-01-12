; The bios loads our code at 0x7c00. We then:
; (a) print an init message to the screen, 
; (b) check that hardware and software interrupts work (for fun),
; (c) load the next stage at the memory address defined by SYSLOAD,
; (d) load the global descriptor table
; (e) move to protected mode
; (f) long jump into the next file, like a boss


ORG     0x7c00              ; This makes life *so* much easier!!!
BITS    16

; Note: If you modify this, remember to modify it in stage two as well.
%define SYSLOAD 0x8000      ; where we'll load the rest of the system


; jump over the includes
jmp start
%include "gdt.asm"
%include "real-mode-interrupts.asm"

align 16
start:
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

    mov     ax,  0x0200                     ; ah determines fg & bg color
    mov     esi, initmsg                    ; move initmsg into si
    mov     edi, 0xb8000                    ; first line of vga memory
    call    printmsg                        ; and print it.


    ; If "OK" appears on the far right, then interrupts work.
    call    fill_interrupt_vector_table
    call    test_real_mode_interrupts


    ; Now we want to load stage two at SYSLOAD 
    ; ========================================
    mov si, DAP         ; address of "disk address packet"
    mov ah, 0x42        ; ah = BIOS call number for this int 0x13 call
    mov dl, 0x80        ; dl = "drive number." Typically 0x80
    int 0x13

    ; Check that the loading went as expected
    cmp dword [SYSLOAD], 0x31c031fa     ; First four bytes of the kernel
    jne loading_is_fucked


    ; Time for protected mode!
    ; ========================
    ; Note: Baremetal uses lgdt [cs:GDTR32], while linux 0.01
    ; uses lgdt [GDTR32] (or the equivalent, translating from 
    ; the as86 syntax Linus used in the linux 0.01 bootloader)
    ; Both work, and I'm fairly sure this isn't by accident, since
    ; our cs should *definitely* be zero, or else something fucked up.
    lgdt [GDTR32]               ; load global descriptor table register
    mov eax, cr0                ; grab control register zero
    or  eax, 0x01               ; set protected mode (PE) bit
    mov cr0, eax                ; ready... set...


    ; This will reload cs with the value 0x0008.
    jmp 0x0008:SYSLOAD    ; go!



DAP:
        db    0x10      ; size of this disk address packet (16)
        db    0         ; always zero
sectrs: dw    16        ; number of sectors (blocks) to copy (1 works)
dstloc: dw    SYSLOAD   ; where to copy the data (offset)
        dw    0x0000    ; where to copy the data (segment)
srcloc: dd    2         ; starting LBA (starts at 0. 2 makes iso happy)
        dd    0         ; used for upper part of 48 bit LBAs


loadfail:   db "Your magic fucked up...", 0x00
loading_is_fucked:
    mov esi, loadfail
    mov edi, 0xb8000
    call printmsg
    jmp $


initmsg:    db "JasonWnix is booting...", 0x00
printmsg:
    ; put string address in si beforehand
    pusha               ; push all general purpose registers
    .getchar:           ; this is our loop label
    lodsb               ; Load byte at address ds:(e)si into al
    cmp al,     0x00    ; If the byte is 0,
    je .done            ; then we're done
    mov word [edi], ax  ; otherwise, write the vga entry (fg4,bg4,byte8)
    add edi, 0x02       ; pointer++, since ebx is a (short *)
    jmp .getchar        ; get the next character
    .done:
    popa                ; pop all general purpose registers
    ret


%define CHARSIZE   2        ; VGA characters are 2 bytes
%define VGAWIDTH   80       ; Rows have 80 == 0xa0 slots
%define VGAHEIGHT  25       ; Cols have 25 == 0x19 slots
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


times 510-($-$$) db 0x00 ; pad remainder of boot sector with zeros
dw 0xAA55                ; the standard pc boot signature
times 512 db 0x00
