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


align 16
start:
    cli
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp
    xor esp, esp
    mov ds,  ax
    mov es,  ax
    mov fs,  ax
    mov gs,  ax
    mov ss,  ax

    ; The BIOS hands us the type of the boot drive in dl
    ; By "type," I mean the value we'll later need to pass into dl
    ; to read data via either CHS or LBA. This is 0x80 for hard drives,
    ; and something else for floppies. Apparently some BIOSes
    ; define bootable USB sticks onto which we've dd'ed an image as
    ; floppies (e.g., my good Asus laptop) while other BIOSes define
    ; those same USB sticks to be hard drives (e.g., my shitty Asus
    ; laptop, which was actually being more friendly here).
    ; Either way, save the drive number for later!

    mov byte [drv], dl                      ; save the drive number
	mov     sp, 0x7c00                      ; set up the stack segment

    mov ebx, 0xb8000 + 5*0xa0
    mov dword [ebx], (0x0700+"0")

    ;call    clear_screen                    ; kill bios boot messages

    mov ebx, 0xb8000 + 6*0xa0
    mov dword [ebx], (0x0700+"1")

    mov     ax,  0x0200                     ; ah determines fg & bg color
    mov     esi, initmsg                    ; move initmsg into si
    mov     edi, 0xb8000                    ; first line of vga memory
    call    printmsg                        ; and print it.

    mov ebx, 0xb8000 + 7*0xa0
    mov dword [ebx], (0x0700+"2")

    ; If "OK" appears on the far right, then interrupts work.
    ;call    fill_interrupt_vector_table
    ;call    test_real_mode_interrupts


    ; Now we want to load stage two at SYSLOAD 
    ; Note: For real hardware, we may have to do this multiple times!
    ; ========================================
    mov si, DAP         ; address of "disk address packet"
    mov ah, 0x42        ; ah = BIOS call number for this int 0x13 call
    mov dl, byte [drv]  ; dl = drive type (0x80 for HDs, etc.)
    int 0x13

    mov ebx, 0xb8000 + 8*0xa0
    mov dword [ebx], (0x0700+"3")


    ; Now we want to load stage two at SYSLOAD
    ; We'll do this cylinder-head-sector style
    ; ========================================
    ; Cylinder  = 0 to 1023 (maybe 4095)
    ; Head      = 0 to 15 (maybe 254, maybe 255)
    ; Sector    = 1 to 63

    ; From the good old RBL ;-)
    ; =========================
    ; AH = 0x02
    ; AL = Number of sectors to read (must be nonzero, and < 128)
    ;      Can't cross a page boundary, or a cylinder boundary
    ; CH = Low eight bits of cylinder number
    ; CL = Sector number 1-63 (bits 0-5)
    ;      High two bits of cylinder (bits 6-7, hard disk only)
    ; DH = Head number
    ; DL = Drive number. For hard disks, this = 1<<7 = 0b10000000 = 0x80
    ; ES:BX -> data buffer

    mov di, 3
    a:
    mov bx, SYSLOAD                 ; es:bx == 0x0000:bx -> buffer
    mov ah, 0x02
    mov al, 0x10                    ; al = total sector count
    mov ch, 0x00                    ; ch: cylinder & 0xff
    mov cl, 0x03 | ((0>>2)&0xc0)    ; cl: sector | ((cylinder>>2)&0xc0)
    mov dh, 0x00                    ; dh: head
    mov dl, byte [drv]              ; dl = drive number. Typically 0x80
    int 0x13
    dec di
    cmp di, 0
    jne a

    mov ebx, 0xb8000 + 9*0xa0
    mov dword [ebx], (0x0700+"4")

    ; Check that the loading went as expected
    ;cmp dword [SYSLOAD], 0x31c031fa ; First four bytes of the kernel
    ;jne loading_is_fucked

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

    mov ebx, 0xb8000 + 10*0xa0
    mov dword [ebx], (0x0700+"5")

    ; This will reload cs with the value 0x0008.
    jmp 0x0008:SYSLOAD    ; go!


%include "boot/gdt.asm"
;%include "boot/real-mode-interrupts.asm"

align 16
loading_is_fucked:
    mov ebx, 0xb8000 + 11*0xa0
    mov dword [ebx], (0x0700+"F")
    mov esi, loadfail
    mov edi, 0xb8000
    call printmsg
    sti
    hlt
    cli
    jmp loading_is_fucked


align 16
printmsg:
    ; put string address in si beforehand
    pusha               ; push all general purpose registers
    cld                 ; clear the direction flag
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
align 16
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


DAP:
        db    0x10      ; size of this disk address packet (16)
        db    0         ; always zero
sectrs: dw    10        ; number of sectors (blocks) to copy (1 works)
dstloc: dw    SYSLOAD   ; where to copy the data (offset)
        dw    0x0000    ; where to copy the data (segment)
srcloc: dd    2         ; starting LBA (starts at 0)
        dd    0         ; used for upper part of 48 bit LBAs

align 16
initmsg:    db "JasonWnix is booting...", 0x00
loadfail:   db "Magic fucked up...", 0x00
drv:        db 0x00

times 510-($-$$) db 0x00 ; pad remainder of boot sector with zeros
dw 0xAA55                ; the standard pc boot signature
times 512 db 0x00
