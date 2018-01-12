; The bios loads our code at 0x7c00. We then:
; (a) print an init message to the screen, 
; (b) check that hardware and software interrupts work (for fun),
; (c) load the next stage at the memory address defined by SYSLOAD,
; (d) load the global descriptor table
; (e) move to protected mode
; (f) long jump into the next file, like a boss


; How to learn from the various bootsectors on my partitions ;)
; sudo head -c +512 /dev/sda  | ndisasm - | grep -C 7 'int 0x.*'

; Make sure the dd worked identically for two different drives, at
; least within the bootsector.
; diff <(sudo head -c +512 /dev/sda11 | hexdump -Cv) \
       <(sudo head -c +512 /dev/sdb   | hexdump -Cv)

; Note: Use SYSBLOCK = (SYSLOAD-0x7c00)/0x200 hack to make iso happy.

BITS    16
ORG     0x7c00                  ; Life was *hard* before we found this!
%define SYSLOAD     0x8000      ; Where we'll load the system
%define SYSBLOCK    4           ; First logical block to load

%macro wait 1
    push    ecx
    mov     ecx, %1
    .nothing:
    dec     ecx
    cmp     ecx, 0
    jne     .nothing
    pop     ecx
%endmacro

align 16
start:
    cli
    xor eax, eax
    mov ds,  ax
    mov es,  ax
    mov fs,  ax
    mov gs,  ax
    mov ss,  ax


    ; The BIOS hands us the type of the boot drive in dl. Save it!
    mov byte [drv], dl                      ; save the drive number
    mov     sp, 0x7c00                      ; set up the stack segment

    call    clear_screen                    ; kill bios boot messages

    ; If "OK" appears on the far right, then interrupts work.
    call    fill_interrupt_vector_table
    call    test_real_mode_interrupts

    ; ==================================================
    ; Time to play chicken with the hardware!
    ; We want to load stage two at SYSLOAD, but hardware
    ; sucks, so we'll just hammer on it until it works.
    ; ==================================================

    fighttothedeath:
    ; While we're here, try an init message
    mov     ax, 0x0700                      ; ah holds fg & bg color
    mov     si, initmsg                     ; move initmsg into si
    mov     di, 0x0000                      ; first line of vga memory
    call    printmsg                        ; and print it.

    ; Try loading stage two using the disk number we got from the BIOS
    mov si, DAP         ; address of "disk address packet"
    mov ah, 0x42        ; ah = BIOS call number for this int 0x13 call
    mov dl, byte [drv]  ; dl = drive number. Typically 0x80
    int 0x13
    cmp dword [SYSLOAD], 0x31c031fa
    je freedom

    ; Same as above, but trying 0x80, instead of number from BIOS
    ;mov si, DAP
    ;mov ah, 0x42
    ;mov dl, 0x80
    ;int 0x13
    ;cmp dword [SYSLOAD], 0x31c031fa
    ;je freedom

    wait 0x1000
    jmp fighttothedeath
    ; ==================================================

    freedom:

    ; Time for protected mode!
    ; ========================
    ; Note: Baremetal uses lgdt [cs:GDTR32], while linux 0.01
    ; uses lgdt [GDTR32] (or the equivalent, translating from 
    ; the as86 syntax Linus used in the linux 0.01 bootloader)
    ; Both work, and I'm fairly sure this isn't by accident, since
    ; our cs should *definitely* be zero, or else something fucked up.
    lgdt [GDTR32]           ; load global descriptor table register
    mov eax, cr0            ; grab control register zero
    or  eax, 0x01           ; set protected mode (PE) bit
    mov cr0, eax            ; ready... set...


    ; This will reload cs with the value 0x0008.
    jmp 0x0008:SYSLOAD    ; go!


%include "boot/gdt.asm"
%include "boot/interrupt16.asm"

align 16
printmsg:
    ; put string address in si beforehand
    pusha
    cld                         ; clear the direction flag
    .getchar:                   ; this is our loop label
    lodsb                       ; Load byte at address ds:(e)si into al
    cmp al,     0x00            ; If the byte is 0,
    je .done                    ; then we're done
    mov word [0xb8000+edi], ax  ; else, write vga entry (fg4,bg4,byte8)
    add di, 0x02                ; pointer++, since ebx is a (short *)
    jmp .getchar                ; get the next character
    .done:
    popa
    ret

align 16
clear_screen:
    ; VGA charsize = 2, screen width = 80, screen height = 25
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

align 16
DAP:
        db    0x10      ; size of this disk address packet (16)
        db    0         ; always zero
sectrs: dw    20        ; number of sectors (blocks) to copy (1 works)
dstloc: dw    SYSLOAD   ; where to copy the data (offset)
        dw    0x0000    ; where to copy the data (segment)
srcloc: dd    SYSBLOCK  ; starting LBA (starts at 0)
        dd    0         ; used for upper part of 48 bit LBAs

initmsg:    db "JasonWnix is booting...", 0x00
drv:        db 0x00

times 510-($-$$) db 0x00 ; pad remainder of boot sector with zeros
dw 0xAA55                ; the standard pc boot signature
times 512*(SYSBLOCK-1)   db 0x00
