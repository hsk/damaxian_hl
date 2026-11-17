# HLANG は HLang のリポジトリの場所（既定は隣の ../hlang）。hlc はそこでビルドする。
# リリースの hlc を使うなら: make HLC=/path/to/hlc HLANG_LIB=/path/to/lib
HLANG ?= ../hlang
HLC ?= $(HLANG)/_build/default/bin/hlc.exe
MACHINE = C-BIOS_MSX1
HLANG_LIB ?= $(abspath $(HLANG)/lib)
export HLANG_LIB
SOURCES = $(wildcard *.hl)

.PHONY: all run clean assets

all: main.rom

# pattern.hl と bg.hl は、元の C 版の pattern.c と bg.c から作る（git submodule update --init が要る）
assets: pattern.hl bg.hl

pattern.hl bg.hl: tools/import_assets.py orig/damaxian_msx/sources/pattern.c orig/damaxian_msx/sources/bg.c
	python3 tools/import_assets.py

main.rom: $(SOURCES)
	$(HLC) main.hl

run: main.rom
	openmsx -machine $(MACHINE) -cart main.rom

clean:
	rm -f main.rom
