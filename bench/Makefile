bench: bench-erqwest bench-katipo bench-hackney

bench-erqwest: cert.crt
	cd .. && rebar3 compile
	ERL_LIBS="$$(cd .. && rebar3 path --lib -s ":")" \
		escript ./bench.escript erqwest

bench-%: cert.crt
	rebar3 as $* compile
	ERL_LIBS="$$(rebar3 as $* path --lib -s ":")" \
		escript ./bench.escript $*

start-nginx: cert.crt
	nginx -p . -c nginx.conf -e /dev/null

cert.crt:
	openssl req -nodes -new -x509 -newkey rsa:4096 -keyout cert.key -out cert.crt -days 365 -subj '/CN=localhost'
