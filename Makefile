CC 	    = gcc
AS      = gas
CFLAGS  = -m32 -ffreestanding -nostdlib -Wall -Wextra
OBJS    = protectedmode.o kmain.o

default:
	make bootloader
	make kernel
	make image

bootloader:
	nasm -f bin -o boot.bin boot.asm

kernel:
	nasm -f elf32 -o protectedmode.{o,asm}
	$(CC) $(CFLAGS) -c kmain.c
	ld -m elf_i386 --oformat=binary -Ttext=0x8000 -o kernel.bin $(OBJS)

image:
	cat boot.bin kernel.bin > jasonwnix

clean:
	rm -f *.bin *.o jasonwnix
