UC = $(shell echo '$1' | tr '[:lower:]' '[:upper:]')

PROJECT	:= 2rx16
AS		:= ca65
LD		:= ld65
MKDIR	:= mkdir -p
RMDIR	:= rmdir -p
CONFIG  := ./$(PROJECT).cfg
ASFLAGS	:= --cpu 65C02 -g
LDFLAGS	:= -C $(CONFIG)
SRC		:= ./src
OBJ		:= ./obj
SRCS	:= $(wildcard $(SRC)/*.s)
OBJS    := $(patsubst $(SRC)/%.s,$(OBJ)/%.o,$(SRCS))
EXE		:= $(call UC,$(PROJECT).PRG)
EXE2	:= ./SECOND.PRG
SDCARD	:= ./sdcard.img
MAPFILE := ./$(PROJECT).map
SYMFILE := ./$(PROJECT).sym

ifdef ASSETBLOB
	ASFLAGS += -D ASSETBLOB=1
endif


default: all

all: $(EXE)

blob: $(EXE2)

$(EXE2):
	make clean
	make all
	(cd scripts; ./create-blob-offsets.py)
	rm -f blob.tmp
	# keep building until the loadfile blob is consistent
	# it seems to take three passes to do so
	until diff -q blob.tmp src/blob_loadfile.inc; do \
		cp -v src/blob_loadfile.inc blob.tmp ; \
		make clean ; \
		ASSETBLOB=1 make all ; \
		(cd scripts; ./create-blob-offsets.py) ; \
	done
	rm -f blob.tmp
	mv -v $(EXE) $(EXE2)
	
$(EXE): $(OBJS) $(CONFIG)
	$(LD) $(LDFLAGS) $(OBJS) -m $(MAPFILE) -Ln $(SYMFILE) extern/zsmkit.lib -o $@ 
	cp -v $(EXE) ROOT/

$(OBJ)/%.o: $(SRC)/%.s $(SRC)/*.inc | $(OBJ)
	$(AS) $(ASFLAGS) $< -o $@

$(OBJ):
	$(MKDIR) $@

$(SDCARD): $(EXE)
	$(RM) $(SDCARD)
	truncate -s 100M $(SDCARD)
	parted -s $(SDCARD) mklabel msdos mkpart primary fat32 2048s -- -1
	mformat -i $(SDCARD)@@1M -v $(call UC,$(PROJECT)) -F
	mcopy -i $(SDCARD)@@1M -o -s -v -m ROOT/* ::

.PHONY: clean run
clean:
	$(RM) $(EXE) $(EXE2) $(OBJS) $(SDCARD) $(MAPFILE) $(SYMFILE) ROOT/*.BIN ROOT/*.PRG

box: $(EXE) $(SDCARD)
	box16 -sdcard $(SDCARD) -prg $(EXE) -run -ram 1024

run: $(EXE) $(SDCARD)
#	x16emu -sdcard $(SDCARD) -prg $(EXE) -debug -scale 2 -run -ram 1024
	x16emu -sdcard $(SDCARD) -prg $(EXE) -debug -scale 2 -run
	
