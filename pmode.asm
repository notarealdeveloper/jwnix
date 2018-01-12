; This is the entry point to the kernel.
; The bootloader uses BIOS calls to load the kernel image (not including
; itself) from disk into memory. This file is loaded starting at 0x10000.
; The bootloader then executes a far jump to 0x1000:0x0000, which jumps
; into this file's code.

%define SYSLOAD     0x8000

section .text
; ====================== ;
; !!! PROTECTED MODE !!! ;
; ====================== ;

%macro outb 2
    mov dx, %0  ; %0 = port
    mov al, %1  ; %1 = byte
    out dx, al
%endmacro

USE32
extern start_kernel
extern pic_remap
global _start
_start:
protectedmode:

    ; Welcome to protected mode! Now you're a man.
    ; ============================================
    ; First, we set all the segment registers that have anything to do
    ; with "data" (i.e., all of them except cs) to the same 4GB data 
    ; descriptor. To see what's going on here, we have to understand the 
    ; different meaning that segment registers have in protected mode, 
    ; (as opposed to the "simpler" meaning they have in real mode)
    ; This difference is explained very well (twice, no less) at
    ; http://geezer.osdevbrasil.net/johnfine/segments.htm
    ; Here's what whatshisface calls the "simple but wrong version"
    ; (though it's true enough to help us understand the right version).
    ; In protected mode the CPU doesn't do the "one nybble shift left"
    ; business to segment registers in order to get a physical address.
    ; In protected mode, the value in a segment register isn't even a 
    ; segment number! It's something called a "selector". Bit 2 of the 
    ; selector tells the CPU whether to use the GDT or LDT. Bits 3 to 15 
    ; of the selector index to one of the descriptors in the GDT or IDT.
    ; Now, we all know that most memory accesses (in all modes) 
    ; implicitly or explicitly use some segment register (ds/es/ss/etc).
    ; So, when we try to execute an instruction in protected mode,
    ; like "mov byte [0x9000], al" the CPU gets the address we actually 
    ; asked for (in this case, 0x9000) and adds it to the "base" value 
    ; from the descriptor to obtain a 32-bit "linear" address
    ; (Aside: what is "the descriptor" in the above sentence?
    ; presumably, "the descriptor" is the descriptor we registered
    ; *for that segment.* Example: below, we put 16 in all the data
    ; segment registers, which essentially associates all those segment
    ; registers with whatever descriptor is found 16 bytes into the
    ; global descriptor table; for us, it's the "data segment descriptor"
    ; that comes 3rd in our gdt, which is 16 bytes after gdt32beg above.)
    ; Okay, where were we? Each descriptor also contains a "limit"
    ; (length minus one) for all segments we choose to associate with
    ; that descriptor. Unlike in real mode, the CPU will generate a 
    ; fault if we attempt to access beyond the limit of a segment.
    ; Bits 0 and 1 of the selector are known as the "RPL". The current 
    ; priviledge level is known as the "CPL". Those values are checked 
    ; against the descriptor priviledge "DPL" to see if the access 
    ; should be permitted.

    ; Note the value below (16) is determined as follows:
    ; Bits 0 and 1: The "RPL" or "Requested privilege level" = 0 (kernel)
    ; Bit 2 tells the CPU whether to use the GDT or LDT (0 for GDT)
    ; Bits 3:16 (should this be 3:32?) point to an entry in the GDT.
    ; Our value below is 16 because the first 3 bits are 0, and our data
    ; selector is located at index 0b0010 = 2 into the GDT.
    cli
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp

    ; Set the data segment registers to use their proper GDT entry
    ; 0b10000. Ignore low 3 bits to get 2, i.e., GDT[2]
    mov eax, 16
    mov ds, eax
    mov es, eax
    mov fs, eax
    mov gs, eax
    mov ss, eax
    mov esp, SYSLOAD    ; Set a known free location for the stack

    mov     ax, 0x0300          ; ah determines the fg and bg color
    mov     esi, protmsg        ; the message to print
    mov     edi, 0xb8000+0xa0   ; base address of vga memory map + 1 line
    call    printmsg

    lidt [IDTR32]               ; load interrupt descriptor table (reg)

    ; Set up interrupts!
    mov edi, 0x69
    mov esi, int_handler
    call load_idt_entry
    int 0x69

    ; Calling sti after setting-up interrupts causes a double fault.
    ; Apparently this is because a timer interrupt is being called.
    ; A temporary fix for this is to set the timer interrupt to be
    ; handled by a routine that does nothing. This prevents the crash.
    ;mov edi, 0x08
    ;mov esi, int_handler_null
    ;call load_idt_entry

    ; Either of these in isolation seems to work equally well
    ; Weird: Also seems to work without either...
    ; Maybe the problem is with the kbd controller?
    outb 0x21, 0xfd    ; dst = port 0x21, src = byte 0xfd
    outb 0xa1, 0xff    ; dst = port 0xa1, src = byte 0xff

    call pic_remap

    outb 0x21, 0xfd    ; dst = port 0x21, src = byte 0xfd
    outb 0xa1, 0xff    ; dst = port 0xa1, src = byte 0xff

    jmp a
a:  jmp b
b:  jmp c
c:

    ;mov ecx, 0x20
    ;boops:
    ;mov edi, ecx
    ;mov esi, int_handler_null
    ;call load_idt_entry
    ;inc ecx
    ;cmp ecx, 0x2f
    ;jne boops

    mov edi, 0x20
    mov esi, int_handler_timer
    call load_idt_entry

    ; I AM getting keyboard interrupts, but something is clearing them!

    ; I can only get keyboard interrupts *before* the timer interrupt
    ; occurs! And it always occurs... and within a fraction of a second.
    mov edi, 0x21
    mov esi, int_handler_kbd
    call load_idt_entry
    cmp byte [0x21*8+5], 0x8e
    jne halt

    sti

    jmp die

    call start_kernel

    ; Now that you're here, you should relax and enjoy this article, 
    ; since it's almost certainly something you've encountered by now :)
    ; http://en.wikipedia.org/wiki/Triple_fault

    jmp halt

die:
    times 10 db 0x90
    jmp die

halt:
    hlt
    jmp halt

int_handler:
    ;cli
    pusha
    mov     ax,  0x0400         ; ah determines the fg and bg color
    mov     esi, idtmsg         ; the message to print
    mov     edi, 0xb8000+2*0xa0 ; base addr of vga memory map + 2 lines
    call    printmsg
    popa
    ;sti
    iret

int_handler_timer:
    cli
    pusha

    mov     ax,  0x0700
    mov     esi, timermsg
    mov     edi, 0xb8000+0*0xa0
    add     edi, dword [LINE]
    add     dword [LINE], 0xa0
    call    printmsg
    outb    0x20, 0x20      ; acknowledge the interrupt to the PIC
    popa
    sti

    int 0x21    ; Gotcha!

    iret


int_handler_kbd:
    cli
    pusha


    .waitforstatus:
    ; Read port 0x64, & check if low bit is 1
    in   al, 0x64
    and  al, 0x01
    cmp  al, 0x01
    jne  .waitforstatus
    ; Read keypress from port 0x60
    in   al, 0x60   ; read information from the keyboard

    ; The following 2 lines are from osdev, and are untested
    mov     ax,  0x0600         ; ah determines the fg and bg color
    mov     esi, kbdmsg         ; the message to print
    mov     edi, 0xb8000+4*0xa0
    add     edi, dword [LINE]
    add     dword [LINE], 0xa0
    call    printmsg

    sti
    outb    0x20, 0x20      ; acknowledge the interrupt to the PIC
    popa
    iret

int_handler_kbd2:
    cli
    pusha
    ; The following 2 lines are from osdev, and are untested
    in      al, 0x60           ; read information from the keyboard
    outb    0x20, 0x20      ; acknowledge the interrupt to the PIC
    mov     ax,  0x0600         ; ah determines the fg and bg color
    mov     esi, kbdmsg2         ; the message to print
    mov     edi, 0xb8000+4*0xa0
    add     edi, dword [LINE]
    add     dword [LINE], 0xa0
    call    printmsg
    popa
    sti
    iret

int_handler_kbd3:
    cli
    pusha
    ; The following 2 lines are from osdev, and are untested
    in      al, 0x60           ; read information from the keyboard
    outb    0x20, 0x20      ; acknowledge the interrupt to the PIC
    mov     ax,  0x0600         ; ah determines the fg and bg color
    mov     esi, kbdmsg3         ; the message to print
    mov     edi, 0xb8000+4*0xa0
    add     edi, dword [LINE]
    add     dword [LINE], 0xa0
    call    printmsg
    popa
    sti
    iret

int_handler_null:
    cli
    pusha
    popa
    outb    0x20, 0x20      ; acknowledge the interrupt to the PIC
    sti
    iret

printmsg:
    ; put string address in si beforehand
    push eax
    push esi
    push edi
    .getchar:           ; this is our loop label
    lodsb               ; Load byte at address ds:(e)si into al
    cmp al,     0x00    ; If the byte is 0,
    je .done            ; then we're done
    mov word [edi], ax  ; otherwise, write the vga entry (fg4,bg4,byte8)
    add edi, 0x02       ; pointer++, since ebx is a (short *)
    jmp .getchar        ; get the next character
    .done:
    pop  edi
    pop  esi
    pop  eax
    ret

; To register an interrupt handler for (say) interrupt 0x20, do
; the following before calling this fucntion:
; mov edi, 0x20
; mov esi, int_handler
load_idt_entry:
    push esi

    ; First, load a skeleton idt entry into the desired idt slot.
    call load_skeleton_idt_entry

    ; Register our interrupt handler
    ; If we're setting (say) int 0x20, this is mov word [0x20*8], si
    mov word [edi*8+0], si

    ; The following two lines set offset bits 16..31 of the idt entry.
    ; This isn't currently necessary, presumably because we're still low
    ; enough in RAM that those bits *are* actually zero.
    ; However, we may move in the future, so lets set-up the high bits
    ; anyway. Keep in mind that I haven't tested this yet, so I'm
    ; not 100% sure the following two lines do the right thing.
    ; They almost certainly do, though.
    shr esi, 16
    mov word [edi*8+6], si

    pop esi
    ret

load_skeleton_idt_entry:
    push eax
    mov dword eax,        [idt_entry_skeleton]
    mov dword [edi*8+0], eax
    mov dword eax,        [idt_entry_skeleton+4]
    mov dword [edi*8+4], eax

    ; Check that we loaded the skeleton idt entry correctly
    cmp byte  [edi*8+5], 0x8e
    jne halt
    pop eax
    ret

section .data
protmsg: db "Entered protected mode!", 0x00
idtmsg:  db "Protected mode software interrupts are working!", 0x00
kbdmsg:  db "Keyboard interrupt handler 1 called", 0x00
kbdmsg2: db "Keyboard interrupt handler 2 called", 0x00
kbdmsg3: db "Keyboard interrupt handler 3 called", 0x00
timermsg: db "Timer interrupt called", 0x00
linkmsg: db "Successfully linked with C!", 0x00
LINE:    dd 0x00000000
; The interrupt descriptor table *register*
; ======================================

align 32
IDTR32:                         ; interrupt descriptor table register
dw (0x100 * 8) - 1              ; limit of IDT (0x100 interrupts)
dd 0x00000000                   ; linear address of IDT
;dd idt32beg                    ; linear address of IDT


; The interrupt descriptor table itself
; ==================================

; Possible IDT gate types (the low nybl in the "type_attr" byte):
; ---------------------------------------------------------------
; 0b0101    0x5    5    80386 32 bit Task gate
; 0b0110    0x6    6    80286 16-bit interrupt gate
; 0b0111    0x7    7    80286 16-bit trap gate
; 0b1110    0xE    14   80386 32-bit interrupt gate
; 0b1111    0xF    15   80386 32-bit trap gate

; IDT gate attrs (the high nybl in the "type_attr" byte):
; -------------------------------------------------------
; P (Present) (bit 47)
;   Set to 1. Can be set to 0 for unused interrupts or for Paging.
; DPL   (bits 45-46)
;   Descriptor Privilege Level. Gate call protection. Specifies which 
;   privilege Level the calling Descriptor minimum should have. 
;   So hardware and CPU interrupts can be protected from beeing called 
;   out of userspace.
; S (Storage Segment) (bit 44)
;   This is 0 for interrupt gates.

; The structure of type_attr
; ==========================
;   7   6   5   4   3   2   1   0
; +---+---+---+---+---+---+---+---+
; | P |  DPL  | S |    GateType   |
; +---+---+---+---+---+---+---+---+
;
;   1    00     0        1110
;
; So set type_attr = 0b10001110 = 0x8e

; The code segment selector for our IDT entries:
; ==============================================
; I think this should be 0x0008, because we do a
; jmp 0x0008:SYSLOAD to enter protected mode
; after setting the PM bit in cr0.


align 32
idt_entry_skeleton:
    ; Skeleton interrupt descriptor table entry
    dw 0x0000   ; offset bits 0..15 (low bits of handler's address)
    dw 0x0008   ; a code segment selector in GDT or LDT (ours in 0x0008)
    db 0x00     ; unused: set to zero
    db 0x8e     ; type and attributes (see above)
    dw 0x0000   ; offset bits 16..31 (high bits of handler's address)

