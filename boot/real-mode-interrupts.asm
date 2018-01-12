; Just for fun, to check that interrupts are working


fill_interrupt_vector_table:
    mov dword       [0x06*4],   invalid_opcode_handler
    mov dword       [0x09*4],   keyboard_interrupt_handler
    mov dword       [0x69*4],   software_interrupt_handler
    ret

test_real_mode_interrupts:
    sti             ; Tell cpu to accept interrupts from peripherals
    int 0x69        ; Test interrupt 0x69 (software interrupt)
    ud2             ; Generate an invalid opcode (hardware interrupt)
    int 0x09        ; Generate a keyboard interrupt (real ones work too)
    cli             ; No hardware interrupts. Soft & NMI ones still work
    ret


; ==================
; INTERRUPT HANDLERS 
; ==================

software_interrupt_handler:
    mov ebx, 0xb8000 + 0xa0 - (2*3)
    mov dword [ebx], (0x0700+"O")
    iret

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

