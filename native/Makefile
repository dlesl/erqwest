PROJECT = erqwest

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
	cargo build --release
	mkdir -p $(OUTPUT)
	cp target/release/$(SO_NAME) $(OUTPUT)

clean:
	rm -f $(OUTPUT)/$(SO_NAME)
	cargo clean
