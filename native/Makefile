PROJECT = erqwest

CARGO_PROFILE ?= release

ERQWEST_FEATURES ?=

ifeq ($(CARGO_PROFILE), release)
	CARGO_OPTS += --release
endif

UNAME_SYS := $(shell uname -s)
ifeq ($(UNAME_SYS), Darwin)
	RUST_SO_EXT := dylib
else
	RUST_SO_EXT := so
endif

PRIV := ../priv
RUST_SO := target/$(CARGO_PROFILE)/lib$(PROJECT).$(RUST_SO_EXT)
# erlang always looks for .so, even on darwin
OUTPUT_SO := $(PRIV)/lib$(PROJECT).so

$(PRIV):
	mkdir -p $(PRIV)

.PHONY: compile
compile: $(PRIV)
	cargo build $(CARGO_OPTS) --features "$(ERQWEST_FEATURES)"
	rm -f $(OUTPUT_SO) # see https://github.com/rusterlium/rustler/issues/128
	cp $(RUST_SO) $(OUTPUT_SO)

clean:
	rm -f $(OUTPUT_SO)
	cargo clean
