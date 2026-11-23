MADS ?= mads
BUILD := ../build
OUT := $(BUILD)/NHAND.COM
LIST := $(BUILD)/NHAND.LST
LABELS := $(BUILD)/NHAND.LAB

.PHONY: all check clean

all: $(OUT)

$(OUT): nhand.asm
	@mkdir -p "$(BUILD)"
	$(MADS) nhand.asm -o:$(OUT) -l:$(LIST) -t:$(LABELS)

check: $(OUT)
	python ../../tools/nhand_handler_check.py

clean:
	rm -f "$(OUT)" "$(LIST)" "$(LABELS)"
