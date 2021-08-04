.PHONY: ci ct dialyzer bench docs

all:
	rebar3 compile

ci:
	$(MAKE) -C native ci
	$(MAKE) ct dialyzer

# using CARGO_PROFILE=debug speeds up the cargo build significantly
ct:
	CARGO_PROFILE=debug rebar3 ct

dialyzer:
	CARGO_PROFILE=debug rebar3 as test dialyzer

docs:
	CARGO_PROFILE=debug rebar3 edoc
