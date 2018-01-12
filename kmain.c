#define CHARSIZE    2
#define VGAWIDTH    80
#define VGAHEIGHT   25
#define VGABASE     0xb8000

#define BYTE0(x) *((char*)(&x)+0)
#define BYTE1(x) *((char*)(&x)+1)
#define VGACHAR(c) (short)((term->color << 8) | (c))

struct Terminal {
    unsigned int  width;
    unsigned int  height;
    unsigned char color;
} __term = {
    .width  = 80,
    .height = 25,
    .color  = 0x05, /* 0x(bg)(fg) */
}, *term = &__term;

unsigned short cursor = 0x0000 + 2*VGAWIDTH;

#define outb(byte, port)  asm("outb %%al,%%dx"::"a"(byte), "d"(port))

void cursor_draw(void)
{
    outb(0x0f, 0x3d4);
    outb(BYTE0(cursor), 0x3d5);
    outb(0x0e, 0x3d4);
    outb(BYTE1(cursor), 0x3d5);
    return;
}

void cursor_right(void)
{
    cursor += 1;
    cursor_draw();
}

void cursor_left(void)
{
    cursor -= 1;
    cursor_draw();
}

void cursor_down(void)
{
    cursor += VGAWIDTH;
    cursor_draw();
}

void cursor_up(void)
{
    cursor -= VGAWIDTH;
    cursor_draw();
}

inline void putc(char c)
{
    unsigned short offset = CHARSIZE * cursor;
    *(unsigned short *)(VGABASE + offset) = VGACHAR(c);
}

void print(char *s)
{
    while (*s != '\0') {
        putc(*s);
        s++; cursor++;
    }
    cursor_draw();
}

void start_kernel(void)
{
    print("Successfully linked with C!");
}

