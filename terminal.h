#ifndef _TERMINAL_H
#define _TERMINAL_H

#include "types.h"

#define VGA_WIDTH           80
#define VGA_HEIGHT          25
#define CURSOR_START_LINE   3
#define COLOR(term)     (term->fg_color | term->bg_color << 4)

/* Cursor functions */
void cursor_init(void);
void cursor_draw(void);

/* Hardware text mode color constants. */
enum vga_color
{
    COLOR_BLACK         = 0,
    COLOR_BLUE          = 1,
    COLOR_GREEN         = 2,
    COLOR_CYAN          = 3,
    COLOR_RED           = 4,
    COLOR_MAGENTA       = 5,
    COLOR_BROWN         = 6,
    COLOR_LIGHT_GREY    = 7,
    COLOR_DARK_GREY     = 8,
    COLOR_LIGHT_BLUE    = 9,
    COLOR_LIGHT_GREEN   = 10,
    COLOR_LIGHT_CYAN    = 11,
    COLOR_LIGHT_RED     = 12,
    COLOR_LIGHT_MAGENTA = 13,
    COLOR_LIGHT_BROWN   = 14,
    COLOR_WHITE         = 15,
};


struct terminal {
    u8      fg_color;
    u8      bg_color;
    u16     *buffer;
    u32     row;
    u32     col;
};


/* uses global term variable */
u16  make_vgaentry(u8 character);
void terminal_set_fg_color(char fg);
void terminal_set_bg_color(char bg);
void terminal_initialize();
void terminal_putentryat(u8 c, u32 x, u32 y);
void terminal_putchar(u8 c);
void terminal_writestring(const char *str);
unsigned char terminal_handle_keyboard_input(void);


#endif /* _TERMINAL_H */
