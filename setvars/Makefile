# Based on the sample Makefile from Roderick W. Smith's EFI Hello World
# example:
# https://www.rodsbooks.com/efi-programming/
ARCH            = $(shell uname -m | sed s,i[3456789]86,ia32,)

OBJS            = main.o
TARGET          = setvars.efi

EFIINC          = /usr/include/efi
EFIINCS         = -I$(EFIINC) -I$(EFIINC)/$(ARCH) -I$(EFIINC)/protocol
LIB             = /usr/lib

ifeq ($(ARCH), x86_64)
    EFILIB	= /usr/lib
else
    EFILIB	= /usr/lib32
endif

EFI_CRT_OBJS    = $(EFILIB)/crt0-efi-$(ARCH).o
EFI_LDS         = $(EFILIB)/elf_$(ARCH)_efi.lds

CFLAGS          = $(EFIINCS) -fno-stack-protector -fpic \
		  -fshort-wchar -mno-red-zone -Wall 
ifeq ($(ARCH), x86_64)
    CFLAGS += -DEFI_FUNCTION_WRAPPER
else
    CFLAGS += -m32
endif

LDFLAGS         = -nostdlib -znocombreloc -T $(EFI_LDS) -shared \
		  -Bsymbolic -L $(EFILIB) -L $(LIB) $(EFI_CRT_OBJS) 

all: $(TARGET)

%.so: $(OBJS)
	ld $(LDFLAGS) $(OBJS) -o $@ -lefi -lgnuefi

%.efi: %.so
	objcopy -j .text -j .sdata -j .data -j .dynamic \
		-j .dynsym  -j .rel -j .rela -j .reloc \
		--target=efi-app-$(ARCH) $^ $@
	cp -f $@ `echo $@ | sed -e "s/.efi/-$(ARCH).efi/"`

.PHONY: clean fat

clean:
	rm -f $(TARGET) $(OBJS) hello.so

fat:
	grub-glue-efi -3 `echo $(TARGET) | sed -e "s/.efi/-ia32.efi/"` -6 `echo $(TARGET) | sed -e "s/.efi/-x86_64.efi/"` -o $(TARGET)
