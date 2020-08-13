# Run make -pn to see the preprocessed Makefile

CC 	    = gcc
AS      = gas
ASM     = nasm
LD32    = ld -m elf_i386
INCLUDE = -I include
CFLAGS  = -m32 -ffreestanding -nostdlib -Wall -Wextra -fno-pic -fno-stack-protector $(INCLUDE)
SYSLOAD = 0x8000

# Make the build nice to look at
Q		= @
MSG		= echo -e "  (MSG)\t   "
ASMSG	= echo -e "  (ASM)\t   "
CCMSG	= echo -e "  (CC) \t   "

TARGET_ARCH	=
CPPFLAGS 	=
MAKEFLAGS  += --no-print-directory --warn-undefined-variables

# Note: entry32.asm has to be first, or else we need a linker script.
#
# Update: We have a linker script! I tried the first thing I could
# think of in a linker script and it magically worked somehow, with
# zero retries. I don't know if that's ever happened before for
# anything at this level. So we now use a linker script for the
# kernel, compile the bootloader and the kernel separately,
# fucking *cat them together* (lol), and then just execute the
# thing and it works because we hooked up the addresses right
# and we still haven't set up virtual memory yet so everything
# makes sense. Hallelujah!
obj :=


# include the description for each module
MODULES := 	kernel drivers
INCLUDE += 	$(patsubst %,-I %,$(MODULES))
include		$(patsubst %,%/Makefile,$(MODULES))

# Names of the targets we'll define later, to build each subdirectory
BUILDMODULES   = $(MODULES:%=build-%)


%.o: %.c
	$(Q)$(CCMSG)"$<"
	$(Q)$(CC) -c -o $@ $< $(CFLAGS)

%.o: %.asm
	$(Q)$(ASMSG)"$<"
	$(Q)$(ASM) -f elf32 -o $@ $<

all: syntax-examples bootloader jasonwnix

syntax-examples:
	$(Q)$(MSG)"Starting build in target $@. Get ready bitches!"
	$(Q)$(MSG)"INCLUDE = $(INCLUDE)"
	$(Q)$(MSG)"MODULES = "$(MODULES)
	$(Q)$(MSG)"BUILDMODULES = "$(patsubst %,build-%,$(MODULES))
	$(Q)$(MSG)$(filter drivers/%,$(obj))
	$(Q)$(MSG)$(foreach o,$(filter kernel/%,$(obj)),$$(basename $o))

bootloader:
	$(Q)$(ASMSG)boot/boot.asm
	$(Q)$(ASM) -f bin -o boot/boot.{bin,asm}

jasonwnix: $(BUILDMODULES)
	$(Q)$(MSG)obj = $(obj)
	$(Q)$(MSG)"Linking object files"
	$(Q)$(LD32) -T linker.ld --oformat=binary -o kernel.bin $(obj)
	$(Q)$(MSG)"Making bootable image"
	$(Q)cat boot/boot.bin kernel.bin > jasonwnix


# Here's where all the magic lives
# Each call to this with some argument "stuff" defines a target called 
# build-stuff whose dependencies are the set of all object files
# in $(obj) that start with stuff/. It may turn out that this fails when
# the .c filename itself contains the module name. If so, try this:
# build-$(1): $(shell echo $(obj) | grep -Eo $(1)"/[^ ]*")
define target-factory
build-$(1): $(filter $(1)/%,  $(obj))
#	$(Q)$(MSG)"In target build-$(1)"
endef

# Like a boss!
# ============
$(foreach mod, $(MODULES), $(eval $(call target-factory,$(mod))))

# The less dynamic way
# $(eval $(call target-factory,kernel))
# $(eval $(call target-factory,drivers))

clean:
	$(Q)$(MSG)"Cleaning source tree"
	$(Q)find -type f -regextype egrep -regex \
		'.*\.(bin|o)' -exec rm '{}' ';'

.PHONY: subdirs $(MODULES)
.PHONY: all clean
