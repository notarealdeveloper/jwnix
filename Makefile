CC 	    = gcc
AS      = gas
CFLAGS  = -m32 -ffreestanding -nostdlib -Wall -Wextra
OBJS    = *.o

default:
	nasm -f bin -o boot.bin boot.asm
	nasm -f bin -o stagetwo.bin stagetwo.asm
	cat boot.bin stagetwo.bin > jasonwnix

clean:
	rm -f *.bin jasonwnix


# Keep these for when we get to protected mode:
# $(CC) $(CFLAGS) -c test.c                   # Gives test.o
# $(CC) $(CFLAGS) -o kernel.bin -Wl,--oformat=binary $(OBJS) -lgcc

