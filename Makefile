# Copyright (c) 2014, Chris Smeele
# All rights reserved.

# Parameters {{{

ifdef VERBOSE
Q :=
E := @true 
else
Q := @
E := @echo 
MAKEFLAGS += --no-print-directory
endif

# }}}
# Package metadata {{{

PACKAGE_NAME    := havik
PACKAGE_VERSION := $(shell git describe --always --dirty)

ifndef PACKAGE_VERSION
PACKAGE_VERSION := 9999
endif

# }}}
# Directories {{{

STAGE1DIR := stage1
STAGE2DIR := stage2
KERNELDIR := kernel

DISKDIR     := disk
LOADERFSDIR := $(DISKDIR)/boot
IMGDIR      := img

# }}}
# Output files {{{

DISKFILE := $(IMGDIR)/$(PACKAGE_NAME)-disk.img
FATFILE  := $(IMGDIR)/fat.img
LOADERFS_RCFILE := $(LOADERFSDIR)/boot/loader.rc
LOADERFS_KERNEL := $(LOADERFSDIR)/boot/$(PACKAGE_NAME)32.elf

OUTFILES := $(DISKFILE) $(FATFILE) $(LOADERFS_KERNEL)

#LOADER_FS_ID   := $(shell printf '%08x' `date +'%s'`)
LOADER_FS_ID   := $(shell printf '%08x' `date +'%Y%m%d3'`)
LOADER_FS_SIZE := 129024

# }}}
# Source and intermediate files {{{

STAGE1_MBR_BIN   := $(STAGE1DIR)/bin/$(PACKAGE_NAME)-stage1-mbr.bin
STAGE1_FAT32_BIN := $(STAGE1DIR)/bin/$(PACKAGE_NAME)-stage1-fat32.bin
STAGE2_BIN       := $(STAGE2DIR)/bin/$(PACKAGE_NAME)-stage2.bin
KERNEL_BIN       := $(KERNELDIR)/bin/$(PACKAGE_NAME)-kernel.elf

DISKFILES        := $(shell find $(DISKDIR) -mindepth 1)

INFILES := $(STAGE1_MBR_BIN) $(STAGE1_FAT32_BIN) $(STAGE2_BIN) $(KERNEL_BIN) $(DISKFILES)

# }}}
# Toolkit {{{

QEMU    ?= qemu-system-i386
SFDISK  ?= sfdisk
MKDOSFS ?= mkfs.vfat
DD      ?= dd
GDB     ?= gdb

# }}}
# Toolkit flags {{{

SFDISKFLAGS := -H 64 -S 32

QEMUFLAGS   := -m 64M -name "osdev" -net none -serial none -vga std \
	-drive file=$(DISKFILE),if=scsi,media=disk,format=raw

QEMUFLAGS_DEBUG := -m 64M -name "osdev" -net none -serial none -vga std \
	-drive file=$(DISKFILE),if=scsi,media=disk,format=raw -s -S

GDBFLAGS := -q -n -x gdbrc

ifdef SERIAL_IO
QEMUFLAGS += -serial stdio -display none
endif

# }}}

-include Makefile.local

# Make targets {{{

.PHONY: all clean clean-all run run-debug debug disk stage1-mbr-bin stage1-fat32-bin stage2-bin kernel-bin

all: $(DISKFILE)

run: $(DISKFILE)
	$(E) "  QEMU     $<"
	$(Q)$(QEMU) $(QEMUFLAGS)

run-debug: $(DISKFILE)
	$(E) "  QEMU     $<"
	$(Q)$(QEMU) $(QEMUFLAGS_DEBUG)

debug:
	$(E) "  GDB   "
	$(Q)$(GDB) $(GDBFLAGS)

clean:
	$(E) "  CLEAN    $(OUTFILES)"
	$(Q)rm -f $(OUTFILES)

clean-all: clean
	$(Q)$(MAKE) -C $(STAGE1DIR) clean
	$(Q)$(MAKE) -C $(STAGE2DIR) clean
	$(Q)$(MAKE) -C $(KERNELDIR) clean

disk: $(DISKFILE)

#$(FATFILE): $(KERNEL_BIN) $(DISKFILES)
$(FATFILE): $(KERNEL_BIN) $(LOADERFS_RCFILE) $(LOADERFS_KERNEL)
	$(E) ""
	$(E) "Loader Filesystem"
	$(E) "================="
	$(Q)mkdir -p $(@D)
	$(E) "  DD       $@"
	$(Q)$(DD) $(DDFLAGS) if=/dev/zero of=$@ bs=512 count=$(LOADER_FS_SIZE) 2>/dev/null
	$(E) "  MKDOSFS  $@"
	$(Q)$(MKDOSFS) -F 32 -i $(LOADER_FS_ID) -n HAVIK $(FATFILE)
	$(E) "  MCOPY    $(LOADERFSDIR)"
	$(Q)mcopy -s $(LOADERFSDIR)/* ::/ -i $@

$(DISKFILE): $(STAGE1_MBR_BIN) $(STAGE2_BIN) $(FATFILE)
	$(E) ""
	$(E) "Disk Image"
	$(E) "=========="
	$(Q)mkdir -p $(@D)
	$(E) "  DD       $@"
	$(Q)$(DD) $(DDFLAGS) if=/dev/zero of=$@ bs=1M count=128 2>/dev/null
	$(E) "  SFDISK   $@"
	$(Q)/bin/echo -e \
	"unit: sectors\n"\
	"\n"\
	""$(DISKFILE)"1 : start=     2048, size=   $(LOADER_FS_SIZE), Id= c, bootable\n"\
	""$(DISKFILE)"2 : start=   131072, size=    65536, Id= 5\n"\
	""$(DISKFILE)"3 : start=        0, size=        0, Id= 0\n"\
	""$(DISKFILE)"4 : start=   196608, size=    65536, Id=83\n"\
	""$(DISKFILE)"5 : start=   131104, size=    12288, Id=83\n"\
	""$(DISKFILE)"6 : start=   143424, size=    53184, Id=83"\
	| $(SFDISK) $(SFDISKFLAGS) $@ >/dev/null
	$(Q)$(DD) $(DDFLAGS) if=$(FATFILE) of=$@ conv=notrunc bs=512 seek=2048 count=$(LOADER_FS_SIZE) 2>/dev/null
	$(E) "  INSTALL  $@"
	$(Q)perl tools/loader-install.pl \
		--mbr \
		--stage1-mbr $(STAGE1_MBR_BIN) \
		--stage2 $(STAGE2_BIN) \
		--stage2-lba 1 \
		--loader-fs-id $(LOADER_FS_ID) \
		--img $@

$(STAGE1_MBR_BIN): stage1-mbr-bin ;

stage1-mbr-bin:
	$(E) ""
	$(E) "Stage 1 (MBR)"
	$(E) "============="
	$(Q)$(MAKE) -C $(STAGE1DIR) bin-mbr

$(STAGE1_FAT32_BIN): stage1-fat32-bin ;

stage1-fat32-bin:
	$(E) ""
	$(E) "Stage 1 (FAT32)"
	$(E) "==============="
	$(Q)$(MAKE) -C $(STAGE1DIR) bin-fat32

$(STAGE2_BIN): stage2-bin ;

stage2-bin:
	$(E) ""
	$(E) "Stage 2"
	$(E) "======="
	$(Q)$(MAKE) -C $(STAGE2DIR) bin

$(KERNEL_BIN): kernel-bin ;

kernel-bin:
	$(E) ""
	$(E) "Kernel"
	$(E) "======"
	$(Q)$(MAKE) -C $(KERNELDIR) bin

$(LOADERFS_KERNEL): $(KERNEL_BIN)
	$(Q)ln -f $< $@

# }}}
