.PHONY: ci ct dialyzer docs clean shell

all:
	rebar3 compile

ci:
	$(MAKE) ct dialyzer ERQWEST_FEATURES=cookies,gzip

# using CARGO_PROFILE=debug speeds up the cargo build significantly
ct:
	CARGO_PROFILE=debug rebar3 ct

dialyzer:
	CARGO_PROFILE=debug rebar3 as test dialyzer

docs:
	CARGO_PROFILE=debug rebar3 ex_doc

clean:
	rebar3 clean
	rm -rf docs
	$(MAKE) -C native clean

shell:
	rebar3 compile
	ERL_LIBS="$$(rebar3 path --lib -s ":")" \
		erl -eval 'logger:set_primary_config(level, debug), application:start(erqwest), erqwest:start_client(c)'

docker-smoke-tests:
	docker build . -f docker_smoke_tests/Dockerfile.musl
