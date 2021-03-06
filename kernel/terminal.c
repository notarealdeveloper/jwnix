#include <terminal.h>
#include <keyboard.h>
#include <stdlib.h>
#include <types.h>

/* Begin cursor functions */
#define CHARSIZE    2
#define VGAWIDTH    80
#define VGAHEIGHT   25
#define VGABASE     0xb8000
#define BYTE0(x) *((char*)(&x)+0)
#define BYTE1(x) *((char*)(&x)+1)

#define outb(byte, port)    \
    asm volatile ("outb %%al,%%dx"::"a"(byte), "d"(port))


unsigned short cursor;  /* Make this depend on term->row and term->col */


struct terminal __term = {
    .fg_color   = COLOR_LIGHT_GREY,
    .bg_color   = COLOR_BLACK,
    .buffer     = (u16*) VGABASE,
    .row        = CURSOR_START_LINE,
    .col        = 0,
}, *term = &__term;

void cursor_draw(void)
{
    /* Update the cursor location in memory */
    cursor = term->col + VGA_WIDTH*term->row;

    /* Then tell the hardware about it */
    outb(0x0f, 0x3d4);
    outb(BYTE0(cursor), 0x3d5);
    outb(0x0e, 0x3d4);
    outb(BYTE1(cursor), 0x3d5);
}

void cursor_init(void)
{
    cursor = 0x0000 + CURSOR_START_LINE*VGAWIDTH;
    cursor_draw();
}

void terminal_set_fg_color(char fg)
{
    term->fg_color = fg;
}

void terminal_set_bg_color(char bg)
{
    term->bg_color = bg;
}


/* uses global term variable */
u16 make_vgaentry(u8 character)
{
    return (u16) character | (u16) COLOR(term) << 8;
}


/* uses global term variable */
void terminal_initialize(void)
{
    u32 x, y, index;
    for (y = 0; y < VGA_HEIGHT; y++) {
        for (x = 0; x < VGA_WIDTH; x++ ) {
            index = y * VGA_WIDTH + x;
            term->buffer[index] = make_vgaentry(' ');
        }
    }
}


/* uses global term variable */
void terminal_putentryat(unsigned char c, unsigned int x, unsigned int y)
{
    u32 index = y * VGA_WIDTH + x;
    term->buffer[index] = make_vgaentry(c);
}



/* uses global term variable */
void terminal_putchar(unsigned char c)
{
    int i;

    if (c == 0x00)
        return;
    else if (c == BS) {
        terminal_putentryat(' ', --term->col, term->row);
        if (term->col == 0) {
            if (term->row == 0) {
                return;
            } else {
                term->col = VGA_WIDTH;
                --term->row;
            }
        }
    } else if (c == LF) {
        term->col = 0, ++term->row;
    } else if (c == TAB) {
        for (i = 0; i < 4; i++)
            terminal_putchar(' ');
    } else {
        terminal_putentryat(c, term->col, term->row);
        if (++term->col == VGA_WIDTH) {
            term->col = 0;
            if (++term->row == VGA_HEIGHT)
                term->row = 0;
        }
    }
    cursor_draw();
}
 
void terminal_writestring(const char *str)
{
    u32 i, len = strlen(str);
    for (i = 0; i < len; i++)
        terminal_putchar(str[i]);
}

void _terminal_print_byte(u8 c)
{
    u8 nybble1   = (c & 0x0f);
    u8 nybble2   = (c & 0xf0) >> 4;
    u8 bytes[16] = {'0','1','2','3','4','5','6','7',
                    '8','9','a','b','c','d','e','f'};
    char hexstr[6] = {'0', 'x', bytes[nybble2], bytes[nybble1], ' ', 0};

    terminal_writestring(hexstr);
}

void terminal_print_byte(u8 c)
{
    u8 nybble1   = (c & 0x0f);
    u8 nybble2   = (c & 0xf0) >> 4;
    u8 bytes[16] = {'0','1','2','3','4','5','6','7',
                    '8','9','a','b','c','d','e','f'};
    char hexstr[6] = {'0', 'x', bytes[nybble2], bytes[nybble1], ' ', 0};

    terminal_writestring(hexstr);
}

void terminal_print_word(u16 c)
{
    u8 nybble1   = (c & 0x000f);
    u8 nybble2   = (c & 0x00f0) >> 4;
    u8 nybble3   = (c & 0x0f00) >> 8;
    u8 nybble4   = (c & 0xf000) >> 12;
    u8 bytes[16] = {'0','1','2','3','4','5','6','7',
                    '8','9','a','b','c','d','e','f'};
    char hexstr[8] = {'0', 'x', bytes[nybble4], bytes[nybble3], 
                                bytes[nybble2], bytes[nybble1], ' ', 0};
    terminal_writestring(hexstr);
}

unsigned char terminal_handle_keyboard_input(void)
{
    unsigned char c = 0;
    extern struct keyboard *kbd;

    c = keyboard_getkey();

    if      (c == RESTING)          return c;
    else if (c == KEY_DN(ALT))      kbd->alt_pressed  = 1;
    else if (c == KEY_UP(ALT))      kbd->alt_pressed  = 0;
    else if (c == KEY_DN(CTRL))     kbd->ctrl_pressed = 1;
    else if (c == KEY_UP(CTRL))     kbd->ctrl_pressed = 0;
    else if ((c == KEY_DN(LSHIFT)) || (c == KEY_DN(RSHIFT)))
        kbd->shift_pressed = 1;
    else if ((c == KEY_UP(LSHIFT)) || (c == KEY_UP(RSHIFT)))
        kbd->shift_pressed = 0;

#define __fun__
#ifdef  __fun__
    else if (c == F1)   term->fg_color = COLOR_GREEN;
    else if (c == F2)   term->fg_color = COLOR_BLUE;
    else if (c == F3)   term->fg_color = COLOR_CYAN;
    else if (c == F4)   term->fg_color = COLOR_RED;
    else if (c == F5)   term->bg_color = COLOR_MAGENTA;
    else if (c == F6)   term->bg_color = COLOR_GREEN;
    else if (c == F7)   term->bg_color = COLOR_BLUE;
    else if (c == F8)   term->bg_color = COLOR_CYAN;
    else if (c == F9)   term->bg_color = COLOR_RED;
    else if (c == F10)  term->bg_color = COLOR_MAGENTA;
    // else if (c == F11)  nasm_function();
    else if (c == F12) {
        term->fg_color = COLOR_LIGHT_GREY;
        term->bg_color = COLOR_BLACK;
    }
#endif

    else if (c <= 0x40)
        (kbd->shift_pressed) ? terminal_putchar(keyboard_upper(c))
                             : terminal_putchar(keyboard_lower(c));
    return c;
}

