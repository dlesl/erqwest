
erqwest
=====

An experimental erlang wrapper for
[reqwest](https://github.com/seanmonstar/reqwest) using
[rustler](https://github.com/rusterlium/rustler). Map-based interface inspired
by [katipo](https://github.com/puzza007/katipo).

Prerequisites
-------------

* Erlang/OTP
* Rust
* Openssl

Or use the provided `shell.nix` if you have nix installed.

Use
---

 ```
$ rebar3 shell
...
Erlang/OTP 24 [erts-12.0.3] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:1] [jit]

Eshell V12.0.3  (abort with ^G)
1> C = erqwest:make_client().
#Ref<0.3377202660.433717249.45961>
2> erqwest:post(C, <<"https://httpbin.org/post">>, #{headers => [{<<"accept">>, <<"application/json">>}], body => <<"hello">>}).
{ok,#{body =>
          <<"{\n  \"args\": {}, \n  \"data\": \"hello\", \n  \"files\": {}, \n  \"form\": {}, \n  \"headers\": {\n    \"Accept\": \"applic"...>>,
      headers =>
          [{<<"date">>,<<"Tue, 27 Jul 2021 17:48:27 GMT">>},
           {<<"content-type">>,<<"application/json">>},
           {<<"content-length">>,<<"331">>},
           {<<"connection">>,<<"keep-alive">>},
           {<<"server">>,<<"gunicorn/19.9.0">>},
           {<<"access-control-allow-origin">>,<<"*">>},
           {<<"access-control-allow-credentials">>,<<"true">>}],
      status => 200}}
 ```


[Benchmarks](bench)
-------------------

[Docs](https://dlesl.github.io/erqwest/)
----

Todo
----

* Shut down tokio event loop cleanly
* Test thoroughly
