
/* Reinitialize the PIC controllers, giving them sensible
 * offsets rather than the defaults of 0x08 and 0x70.
 */

#define PIC1_CMD        0x20        /* IO base address for master PIC */
#define PIC1_DATA       0x21        /* IO base address for slave PIC */
#define PIC2_CMD        0xA0
#define PIC2_DATA       0xA1

#define ICW1_ICW4       0x01        /* ICW4 (not) needed */
#define ICW1_SINGLE     0x02        /* Single (cascade) mode */
#define ICW1_INTERVAL4  0x04        /* Call address interval 4 (8) */
#define ICW1_LEVEL      0x08        /* Level triggered (edge) mode */
#define ICW1_INIT       0x10        /* Initialization - required! */
 
#define ICW4_8086        0x01       /* 8086/88 (MCS-80/85) mode */
#define ICW4_AUTO        0x02       /* Auto (normal) EOI */
#define ICW4_BUF_SLAVE   0x08       /* Buffered mode/slave */
#define ICW4_BUF_MASTER  0x0C       /* Buffered mode/master */
#define ICW4_SFNM        0x10       /* Special fully nested (not) */

static inline void outb(unsigned short port, unsigned char val)
{
    asm volatile ( "outb %0, %1" : : "a"(val), "Nd"(port) );
}

static inline unsigned char inb(unsigned short port)
{
    unsigned char ret;
    asm volatile ( "inb %1, %0" : "=a"(ret) : "Nd"(port) );
    return ret;
}

/*
 * offset1 - vector offset for master PIC
 *           vectors on the master become offset1 ... offset1 + 7
 * offset2 - vector offset for slave PIC
 *           vectors on the slave  become offset2 ... offset2 + 7
 */

void pic_remap()
{
   /* From http://wiki.osdev.org/PIC#Protected_Mode
    * In protected mode, the IRQs 0 to 7 conflict with the CPU
    * exception which are reserved by Intel up until 0x1F. (It was an
    * IBM design mistake.) Consequently it is difficult to tell the
    * difference between an IRQ or an software error. It is thus
    * recommended to change the PIC's offsets (also known as remapping
    * the PIC) so that IRQs use non-reserved vectors. A common choice
    * is to move them to the beginning of the available range (IRQs
    * 0..0xF -> INT 0x20..0x2F). For that, we need to set the master
    * PIC's offset to 0x20 and the slave's to 0x28.
    */

    int pic1_offset = 0x20;     // Master PIC will have IRQs 0x20-0x27
    int pic2_offset = 0x28;     // Slave  PIC will have IRQs 0x28-0x2f

    unsigned char a1, a2; 
    a1 = inb(PIC1_DATA);        // Save master's interrupt mask
    a2 = inb(PIC2_DATA);
 
    // starts the initialization sequence (in cascade mode)
    outb(PIC1_CMD, ICW1_INIT + ICW1_ICW4); // Data = 0x11. 0x10 works too
    outb(PIC2_CMD, ICW1_INIT + ICW1_ICW4);

    // ICW2: Master PIC vector offset
    outb(PIC1_DATA, pic1_offset);

    // ICW2: Slave PIC vector offset
    outb(PIC2_DATA, pic2_offset);

    // ICW3: tell Master PIC there's a slave PIC at IRQ2 (0b00000100 = 4)
    outb(PIC1_DATA, 0b00000100);

    // ICW3: tell Slave PIC its cascade identity (0b00000010 = 2)
    outb(PIC2_DATA, 0b00000010);
 
    // ICW4: Seems to work equally well without these.
    outb(PIC1_DATA, ICW4_8086);
    outb(PIC2_DATA, ICW4_8086);
 
    // Put the interrupt masks back how they were when we started.
    outb(PIC1_DATA, a1);
    outb(PIC2_DATA, a2);
}

