TOOL_DIR        := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

MINIFIER_COMMIT := d024b1510f8cae5de14e405e9309404f436b68e5
MINIFIER_URL    := https://raw.githubusercontent.com/Zuzzuc/Bash-minifier/$(MINIFIER_COMMIT)/Minify.sh
MINIFIER        := $(TOOL_DIR)lib/vendor/Minify.sh

GENERATOR_AWK   := $(TOOL_DIR)generate_usage_help.awk
INJECTOR_AWK    := $(TOOL_DIR)inject_usage_help.awk

BUILD_DIR       := build

SRC_ALL         := $(wildcard *.src.bash)
FILES           ?= $(SRC_ALL)

BASENAMES       := $(basename $(basename $(notdir $(FILES))))

OUT             := $(addprefix $(BUILD_DIR)/,$(addsuffix .bash,$(BASENAMES)))
HELP_MD         := $(addprefix $(BUILD_DIR)/,$(addsuffix .help.md,$(BASENAMES)))
MIN_BASH        := $(addprefix $(BUILD_DIR)/,$(addsuffix .min.bash,$(BASENAMES)))
FINAL_OUT       := $(addsuffix .bash,$(BASENAMES))

.PHONY: all compile fetch-minifier test clean $(BASENAMES)

.SECONDARY: $(HELP_MD) $(MIN_BASH) $(OUT)

all: compile

compile: $(FINAL_OUT)

$(BASENAMES): %: %.bash

fetch-minifier: $(MINIFIER)

$(MINIFIER):
	mkdir -p "$(dir $@)"
	curl -fsSL "$(MINIFIER_URL)" -o "$@"
	chmod 755 "$@"

$(BUILD_DIR):
	mkdir -p "$@"

$(BUILD_DIR)/%.help.md: %.src.bash $(GENERATOR_AWK) | $(BUILD_DIR)
	awk -f "$(GENERATOR_AWK)" "$<" > "$@"

$(BUILD_DIR)/%.min.bash: %.src.bash $(MINIFIER) | $(BUILD_DIR)
	bash "$(MINIFIER)" < "$<" > "$@"

$(BUILD_DIR)/%.bash: $(BUILD_DIR)/%.min.bash $(BUILD_DIR)/%.help.md $(INJECTOR_AWK) | $(BUILD_DIR)
	awk -v help_file="$(BUILD_DIR)/$*.help.md" -f "$(INJECTOR_AWK)" "$<" > "$@"
	chmod 755 "$@"

%.bash: $(BUILD_DIR)/%.bash
	cp "$<" "$@"
	chmod 755 "$@"

test:
	bats "$(TOOL_DIR)tests"

clean:
	rm -rf "$(BUILD_DIR)"
	rm -f $(FINAL_OUT)
