CC 	    = gcc
AS      = gas
CFLAGS  = -m32 -ffreestanding -nostdlib -Wall -Wextra
OBJS    = *.o

default:
	nasm -f bin -o boot.bin boot.asm
	nasm -f bin -o stagetwo.bin stagetwo.asm
	# Try to move to this:
	# Weirdly, this gives the 32! message, but not the blue message...
	# This has to be because my --oformat=binary strategy is treating
	# the binary's .data differently, since a string in the .data section
	# is the only thing behaving unexpectedly. Look into this!!!
	#nasm -f elf32 -o stagetwo.o stagetwo.asm
	#ld -m elf_i386 --oformat=binary -o stagetwo.bin stagetwo.o
	cat boot.bin stagetwo.bin > jasonwnix

clean:
	rm -f *.bin jasonwnix


# Keep these for when we get to protected mode:
# $(CC) $(CFLAGS) -c test.c                   # Gives test.o
# $(CC) $(CFLAGS) -o kernel.bin -Wl,--oformat=binary $(OBJS) -lgcc

