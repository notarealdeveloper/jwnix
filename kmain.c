#include "keyboard.h"
#include "terminal.h"

void print_init_msg(void)
{
    terminal_set_fg_color(COLOR_MAGENTA);
    terminal_writestring("Successfully linked with C!\n");
    terminal_set_fg_color(COLOR_LIGHT_GREY);
}

void start_kernel(void)
{
    cursor_init();
    print_init_msg();

    while (1) {
        terminal_handle_keyboard_input();
    }
}

