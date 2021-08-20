
erqwest
=======

An experimental erlang wrapper for
[reqwest](https://github.com/seanmonstar/reqwest) using
[rustler](https://github.com/rusterlium/rustler). Map-based interface inspired
by [katipo](https://github.com/puzza007/katipo).

How it works
------------

HTTP requests are performed asynchronously on a [tokio](https://tokio.rs/)
`Runtime` and the responses returned as an erlang message.

Features
--------

* HTTP/1.1 and HTTP/2 with connection keepalive/reuse
* Configurable SSL support, uses system root certificates by default
* Sync and async interfaces
* Proxy support
* Optional cookies support
* Optional gzip support

Prerequisites
-------------

* Erlang/OTP
* Rust
* Openssl (not required on mac)

Or use the provided `shell.nix` if you have nix installed.

Usage
---

### Start a client

``` erlang
ok = application:ensure_started(erqwest),
ok = erqwest:start_client(default).
```

This registers a client under the name `default`. The client maintains an
internal connection pool. 

### Synchronous interface

#### No streaming

 ``` erlang
 {ok, #{status := 200, body := Body}} = 
     erqwest:get(default, <<"https://httpbin.org/get">>),

 {ok, #{status := 200, body := Body1}} =
     erqwest:post(default, <<"https://httpbin.org/post">>,
                  #{body => <<"data">>}).
 ```
 
#### Stream request body

 ``` erlang
 {handle, H} = erqwest:post(default, <<"https://httpbin.org/post">>,
                            #{body => stream}),
 ok = erqwest:send(H, <<"data, ">>),
 ok = erqwest:send(H, <<"more data.">>),
 {ok, #{body := Body}} = erqwest:finish_send(H).
 ```

#### Stream response body

 ``` erlang
 {ok, #{body := Handle}} = erqwest:get(default, <<"https://httpbin.org/stream-bytes/1000">>,
                                       #{response_body => stream}),
 ReadAll = fun Self() ->
               case erqwest:read(Handle, #{length => 0}) of
                 {ok, Data} ->
                   [Data];
                 {more, Data} ->
                   [Data|Self()]
               end
           end,
 1000 = iolist_size(ReadAll()).
 ```

#### Conditionally consume response body

 ``` erlang
 {ok, Resp} = erqwest:get(default, <<"https://httpbin.org/status/200,500">>,
                          #{response_body => stream}),
 case Resp of
   #{status := 200, body := Handle} ->
     {ok, <<>>} = erqwest:read(Handle),
   #{status := BadStatus, body := Handle} ->
     %% ensures the connection is closed/can be reused immediately
     erqwest:cancel(Handle),
     io:format("Status is ~p, not interested~n", [BadStatus])
 end.
 ```


### Asynchronous interface

``` erlang
erqwest_async:req(default, self(), Ref=make_ref(), 
                  #{method => get, url => <<"https://httpbin.org/get">>}),
receive
    {erqwest_response, Ref, reply, #{body := Body}} -> Body
end.
```

See the [docs](https://dlesl.github.io/erqwest/) for more details and and the
[test suite](test/erqwest_SUITE.erl) for more examples.

[Docs](https://dlesl.github.io/erqwest/)
----

[Benchmarks](bench)
-------------------
