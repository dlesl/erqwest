.PHONY: ci ct dialyzer docs clean

all:
	rebar3 compile

ci:
	$(MAKE) ct dialyzer ERQWEST_FEATURES=cookies,gzip

# using PROFILE=debug speeds up the cargo build significantly
ct:
	PROFILE=debug rebar3 ct

dialyzer:
	PROFILE=debug rebar3 as test dialyzer

docs:
	PROFILE=debug rebar3 edoc

clean:
	rebar3 clean
