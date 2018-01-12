#define CURSOR      0xc000
#define CHARSIZE    2
#define VGAWIDTH    80
#define VGAHEIGHT   25
#define VGABASE     0xb8000

unsigned short cursor = 0x0000 + 4*(0xa0); /* New cursor location */


void nasmfunc(void);

void gccfunc(void)
{
    nasmfunc();
}

