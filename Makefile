CC 	    = gcc
AS      = gas
CFLAGS  = -m32 -ffreestanding -nostdlib -Wall -Wextra
OBJS    = *.o

default:
	make bootloader
	make kernel
	make image

bootloader:
	nasm -f bin -o boot.bin boot.asm

kernel:
	nasm -f elf32 -o protectedmode.{o,asm}
	$(CC) $(CFLAGS) -c test.c                   # Gives test.o
	# $(CC) $(CFLAGS) -o kernel.bin -Wl,--oformat=binary $(OBJS) -lgcc
	ld -m elf_i386 --oformat=binary -Ttext=0x8000 -o kernel.bin $(OBJS)

image:
	cat boot.bin kernel.bin > jasonwnix

clean:
	rm -f *.bin *.o jasonwnix
