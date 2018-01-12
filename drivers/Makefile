#CC 	    = gcc
#AS      = gas
#ASM     = nasm
#LD32    = ld -m elf_i386
#INCLUDE = -I .
#CFLAGS  = -m32 -ffreestanding -nostdlib -Wall -Wextra $(INCLUDE)
#DEPS    = *.h
#OBJ     = keyboard.o

#%.o: %.c %.h $(DEPS)
#	$(CC) -c -o $@ $< $(CFLAGS)

#all: $(OBJ)

#clean:
#	rm -f *.o


obj += drivers/keyboard.o
obj += drivers/pic.o
