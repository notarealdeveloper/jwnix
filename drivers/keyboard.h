#ifndef _KEYBOARD_H
#define _KEYBOARD_H

#define NUL         0x00
#define ESC         0x1b
#define BS          0x08
#define TAB         0x09
#define LF          0x0a

#define RESTING     0x9c
#define CTRL        0x1d
#define ALT         0x38
#define LSHIFT      0x2a
#define RSHIFT      0x36
#define KEY_DN(c)   c
#define KEY_UP(c)  (c | 0x80)

/* Note: define macros for all the keys later... or not */
#define F1          0x3b
#define F2          0x3c
#define F3          0x3d
#define F4          0x3e
#define F5          0x3f
#define F6          0x40
#define F7          0x41
#define F8          0x42
#define F9          0x43
#define F10         0x44
#define F11         0x57
#define F12         0x58

unsigned char keyboard_upper(unsigned char c);
unsigned char keyboard_lower(unsigned char c);
unsigned char keyboard_getkey(void);

extern unsigned char lowerkeys[];
extern unsigned char upperkeys[];
extern unsigned char funnykeys[];

struct keyboard {
    unsigned char   shift_pressed;
    unsigned char   ctrl_pressed;
    unsigned char   alt_pressed;
    unsigned char   key;
    unsigned char   last_key;
};

/* 
Unhandled scancodes. (Remember them anyway)
0x3a: capslock
0x45: numlock
0x46: scrlock
0x53: .
*/

#endif /* _KEYBOARD_H */
