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
SDCARD2	:= ./sdcard2.img
MAPFILE := ./$(PROJECT).map
SYMFILE := ./$(PROJECT).sym
GIT_REV_BIN := ./ROOT/GIT-REV.BIN

ifdef ASSETBLOB
	ASFLAGS += -D ASSETBLOB=1
endif

default: all

all: $(EXE)

blob: clean $(EXE2)

blobcard: $(SDCARD2)

$(EXE2):
	make clean
	make all
	(cd scripts; ./create-blob-offsets.py)
	rm -f blob.tmp
	# keep building until the loadfile blob is consistent
	# it seems to take three passes to do so
	until diff -q blob.tmp src/blob_loadfile.inc; do \
		cp -v src/blob_loadfile.inc blob.tmp && \
		make clean && \
		ASSETBLOB=1 make all && \
		(cd scripts; ./create-blob-offsets.py) ; \
	done
	rm -f blob.tmp
	mv -v $(EXE) $(EXE2)

$(EXE): $(OBJS) $(CONFIG)
	$(LD) $(LDFLAGS) $(OBJS) -m $(MAPFILE) -Ln $(SYMFILE) extern/zsmkit.lib -o $@
ifndef ASSETBLOB
	cp -v $(EXE) ROOT/
endif

$(GIT_REV_BIN):
	/bin/echo -n '.byte "' > $@
	git diff --quiet && /bin/echo -n $$(git rev-parse --short=8 HEAD || /bin/echo "00000000") || /bin/echo -n $$(/bin/echo -n $$(git rev-parse --short=7 HEAD || /bin/echo "0000000"); /bin/echo -n '+') >> $@
	/bin/echo '",0' >> $@

$(OBJ)/%.o: $(SRC)/%.s $(SRC)/*.inc | $(OBJ) $(GIT_REV_BIN)
	$(AS) $(ASFLAGS) $< -o $@

$(OBJ):
	$(MKDIR) $@

$(SDCARD): $(EXE)
	$(RM) $(SDCARD)
	truncate -s 32M $(SDCARD)
	parted -s $(SDCARD) mklabel msdos mkpart primary fat32 2048s -- -1
	mformat -i $(SDCARD)@@1M -v $(call UC,$(PROJECT)) -F
	mcopy -i $(SDCARD)@@1M -o -s -v -m ROOT/* ::

$(SDCARD2): $(EXE2)
	$(RM) $(SDCARD2)
	truncate -s 32M $(SDCARD2)
	parted -s $(SDCARD2) mklabel msdos mkpart primary fat32 2048s -- -1
	mformat -i $(SDCARD2)@@1M -v $(call UC,$(PROJECT)) -F
	mcopy -i $(SDCARD2)@@1M -o -s -v -m SECOND.PRG REALITY.X16 ::

.PHONY: clean run blobrun box blobbox
clean:
	$(RM) $(EXE) $(EXE2) $(OBJS) $(SDCARD) $(SDCARD2) $(MAPFILE) $(SYMFILE) ROOT/*.BIN ROOT/*.PRG

box: $(EXE) $(SDCARD)
	box16 -sdcard $(SDCARD) -prg $(EXE) -run

run: $(EXE) $(SDCARD)
	x16emu -sdcard $(SDCARD) -prg $(EXE) -debug -scale 2 -run

blobbox: $(EXE2) $(SDCARD2)
	box16 -sdcard $(SDCARD2) -prg $(EXE2) -run

blobrun: $(EXE2) $(SDCARD2)
	x16emu -sdcard $(SDCARD2) -prg $(EXE2) -debug -scale 2 -run

