#include <keyboard.h>

struct keyboard  __kbd = {
    .shift_pressed  = 0,
    .ctrl_pressed   = 0,
    .alt_pressed    = 0,
    .key            = 0,
    .last_key       = 0,
};

struct keyboard *kbd = &__kbd;

unsigned char lowerkeys[] = {
    NUL,  ESC,  '1',  '2',  '3',  '4',  '5',  '6', /* 0x00 - 0x07 */
    '7',  '8',  '9',  '0',  '-',  '=',  BS,   TAB, /* 0x08 - 0x0f */
    'q',  'w',  'e',  'r',  't',  'y',  'u',  'i', /* 0x10 - 0x17 */
    'o',  'p',  '[',  ']',  LF,   CTRL, 'a',  's', /* 0x18 - 0x1f */
    'd',  'f',  'g',  'h',  'j',  'k',  'l',  ';', /* 0x20 - 0x27 */
    '\'', '`',  LSHIFT,'\\','z',  'x',  'c',  'v', /* 0x28 - 0x2f */
    'b',  'n',  'm',  ',',  '.',  '/',  'X',  'X', /* 0x30 - 0x37 */
    'X',  ' ',  'X',  'X',  'X',  'X',  'X',  'X', /* 0x38 - 0x3f */
};

unsigned char upperkeys[] = {
    NUL,  ESC,  '!',  '@',  '#',  '$',  '%',  '^', /* 0x00 - 0x07 */
    '&',  '*',  '(',  ')',  '_',  '+',  BS,   TAB, /* 0x08 - 0x0f */
    'Q',  'W',  'E',  'R',  'T',  'Y',  'U',  'I', /* 0x10 - 0x17 */
    'O',  'P',  '{',  '}',  LF,   CTRL, 'A',  'S', /* 0x18 - 0x1f */
    'D',  'F',  'G',  'H',  'J',  'K',  'L',  ':', /* 0x20 - 0x27 */
    '"',  '~',  LSHIFT,'|', 'Z',  'X',  'C',  'V', /* 0x28 - 0x2f */
    'B',  'N',  'M',  '<',  '>',  '?',  'X',  'X', /* 0x30 - 0x37 */
    'X',  ' ',  'X',  'X',  'X',  'X',  'X',  'X', /* 0x38 - 0x3f */
};

/* Make this interrupt-driven as soon as you get protected mode
 * interrupts working! Just have to set-up the IDT!!! */
unsigned char keyboard_getkey(void)
{
    /* Can also remove final movb, and change last line to :"=a"(c):: */
    unsigned char c = 0;
    asm ("waitforstatus%=:\n\t"
        /* Read port 0x64, & check if low bit is 1 */
        "in   $0x64, %%al\n\t"
        "andb $0x01, %%al\n\t"
        "cmpb $0x01, %%al\n\t"
        "jne  waitforstatus%=\n\t"
        /* Read keypress from port 0x60 */
        "in   $0x60, %%al\n\t"
        "movb %%al, %0\n\t"
        :"=r"(c)::"al"
    );

    return c;
}


unsigned char keyboard_upper(unsigned char c)
{
    return upperkeys[c];
}

unsigned char keyboard_lower(unsigned char c)
{
    return lowerkeys[c];
}
