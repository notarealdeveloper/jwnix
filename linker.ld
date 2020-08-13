ENTRY(_start)

/* Hook all the various object files together into
 * one thing that runs somehow depite the insanity. */
SECTIONS
{
    /* put this stuff at 0x8000, cuz that's
     * where the bootloader is gonna jump to. */
	. = 0x8000;

    /* code */
	.text : { *(.text); }

    /* read-only data */
	.rodata : { *(.rodata); }

	/* read-write data (initialized global stuff) */
	.data : { *(.data); }

	/* read-write data (uninitialized global stuff, and stack) */
	.bss : { *(.bss); }
}
