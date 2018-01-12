#include <terminal.h>
#include <keyboard.h>

void print_init_msg(void)
{
    terminal_set_fg_color(COLOR_MAGENTA);
    terminal_writestring("Successfully linked with C!\n");
    terminal_set_fg_color(COLOR_LIGHT_GREY);
}

char *videomode             = (char *)0x0449; // byte
char *video_base_io_port    = (char *)0x0463; // word
char *hard_drives_detected  = (char *)0x0475; // byte
char *num_text_columns      = (char *)0x044A; // word
char *keyboard_buffer_start = (char *)0x0480; // word
char *keyboard_buffer_end   = (char *)0x0482; // word

static void print_bios_data_area_info(void)
{
    //terminal_set_fg_color(COLOR_LIGHT_BLUE);
    //terminal_writestring("======================================\n");
    //terminal_set_fg_color(COLOR_WHITE);
    //terminal_writestring("Reading the BIOS data area\n");
    terminal_set_fg_color(COLOR_LIGHT_GREEN);

    terminal_writestring("Video mode is: ");
    terminal_print_byte(*videomode); /* 0x03 = 16 color 80*25 textmode */
    terminal_writestring("\n");

    terminal_writestring("Video base I/O port is: ");
    terminal_print_word(*video_base_io_port);
    terminal_writestring("\n");

    terminal_writestring("Number of hard drives detected: ");
    terminal_print_byte(*hard_drives_detected);
    terminal_writestring("\n");

    terminal_writestring("Number of columns (text mode): ");
    terminal_print_word(*num_text_columns);
    terminal_writestring("\n");

    terminal_writestring("Keyboard buffer start: ");
    terminal_print_word(*keyboard_buffer_start);
    terminal_writestring("\n");

    terminal_writestring("Keyboard buffer end:   ");
    terminal_print_word(*keyboard_buffer_end);
    terminal_writestring("\n");

    terminal_set_fg_color(COLOR_LIGHT_BLUE);
    terminal_writestring("======================================\n");
    terminal_set_fg_color(COLOR_LIGHT_GREY);
}


void start_kernel(void)
{
    cursor_init();
    print_init_msg();
    print_bios_data_area_info();

    /* Idle loop. Stop CPU until next interrupt. */
    while (1) asm("hlt\n");
}

