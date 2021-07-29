PROJECT = erqwest

PROFILE ?= release

ifeq ($(PROFILE), release)
	CARGO_OPTS += --release
endif

UNAME_SYS := $(shell uname -s)
ifeq ($(UNAME_SYS), Darwin)
	SO_EXT := dylib
else
	SO_EXT := so
endif

SO_NAME := lib$(PROJECT).$(SO_EXT)
OUTPUT := ../priv

.PHONY: compile
compile:
	cargo build $(CARGO_OPTS)
	mkdir -p $(OUTPUT)
	rm -f $(OUTPUT)/$(SO_NAME) # see https://github.com/rusterlium/rustler/issues/128
	cp target/$(PROFILE)/$(SO_NAME) $(OUTPUT)

clean:
	rm -f $(OUTPUT)/$(SO_NAME)
	cargo clean
