.PHONY: ci ct dialyzer bench docs

all:
	rebar3 compile

ci:
	$(MAKE) -C native ci
	$(MAKE) ct dialyzer

# using PROFILE=debug speeds up the cargo build significantly
ct:
	PROFILE=debug rebar3 ct

dialyzer:
	PROFILE=debug rebar3 as test dialyzer

docs:
	PROFILE=debug rebar3 edoc
