.PHONY: ci ct dialyzer bench

all:
	rebar3 compile

ci: ct dialyzer

ct:
	PROFILE=debug rebar3 ct

dialyzer:
	PROFILE=debug rebar3 as test dialyzer
