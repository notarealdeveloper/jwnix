CC 	    = gcc
AS      = gas
CFLAGS  = -m32 -ffreestanding -nostdlib -Wall -Wextra -I.
OBJS    = pmode.o kmain.o keyboard.o terminal.o string.o

default:
	make bootloader
	make kernel
	make image

bootloader:
	nasm -f bin -o boot.bin boot.asm

kernel:
	# Everything past the bootloader is compiled to elf so we can easily
	# link, and then stripped down to raw binary at the end.
	nasm -f elf32 -o pmode.{o,asm}
	$(CC) $(CFLAGS) -c *.c
	# ld -m elf_i386 --oformat=binary -Ttext=0x0000 -o kernel.bin $(OBJS)
	ld -m elf_i386 --oformat=binary  -Ttext=0x8400 -o kernel.bin $(OBJS)

image:
	# Original gangsta ;-)
	cat boot.bin kernel.bin > jasonwnix

clean:
	rm -f *.bin *.o # jasonwnix
