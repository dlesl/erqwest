.PHONY: ci ct dialyzer bench

all:
	rebar3 compile

ci: ct dialyzer

# using PROFILE=debug speeds up the cargo build significantly
ct:
	PROFILE=debug rebar3 ct

dialyzer:
	PROFILE=debug rebar3 as test dialyzer

.PHONY: docs
docs:
	PROFILE=debug rebar3 edoc
