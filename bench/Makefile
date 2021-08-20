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

streaming-download:
	cd .. && rebar3 compile
	(sleep 5 && printf "HTTP/1.1 200 OK\r\n\r\n") | cat - /dev/zero | nc -l 8182 &
	ERL_LIBS="$$(cd .. && rebar3 path --lib -s ":")" \
		escript ./streaming_download.escript http://localhost:8182

streaming-upload:
	cd .. && rebar3 compile
	nc -l 8182 > /dev/null &
	ERL_LIBS="$$(cd .. && rebar3 path --lib -s ":")" \
		escript ./streaming_upload.escript http://localhost:8182
