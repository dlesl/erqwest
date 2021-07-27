erqwest
=====

An experimental erlang wrapper for
[reqwest](https://github.com/seanmonstar/reqwest) using
[rustler](https://github.com/rusterlium/rustler). Map-based interface inspired
by [katipo](https://github.com/puzza007/katipo).

Use
---

 ```
$ rebar3 shell
...
1> C = erqwest:make_client().
#Ref<0.1971165508.780533761.175600>
2> erqwest:req(C, #{url => <<"https://httpbin.org/post">>, headers => [{<<"accept">>, <<"application/json">>}], method => post, body => <<"hello">>}).
{ok,#{body =>
          <<"{\n  \"args\": {}, \n  \"data\": \"hello\", \n  \"files\": {}, \n  \"form\": {}, \n  \"headers\": {\n    \"Accept\": \"applic"...>>,
      code => 200,
      headers =>
          [{<<"date">>,<<"Mon, 26 Jul 2021 21:27:25 GMT">>},
           {<<"content-type">>,<<"application/json">>},
           {<<"content-length">>,<<"331">>},
           {<<"connection">>,<<"keep-alive">>},
           {<<"server">>,<<"gunicorn/19.9.0">>},
           {<<"access-control-allow-origin">>,<<"*">>},
           {<<"access-control-allow-credentials">>,<<"true">>}]}}

 ```

Todo
----

* Shut down tokio event loop cleanly
* Test thoroughly
* Benchmark
