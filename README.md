
erqwest
=====

An experimental erlang wrapper for
[reqwest](https://github.com/seanmonstar/reqwest) using
[rustler](https://github.com/rusterlium/rustler). Map-based interface inspired
by [katipo](https://github.com/puzza007/katipo).

How it works
------------

HTTP requests are performed asynchronously on a [tokio](https://tokio.rs/)
`Runtime` and the responses returned as an erlang message.

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
ok = erqwest:start_client(default).
```

This registers a client under the name `default`. The client maintains an
internal connection pool. 

### Synchronous interface
 ``` erlang
{ok, #{status := 200}} = erqwest:get(default, <<"https://httpbin.org/get">>).
 ```
 
### Asynchronous interface

``` erlang
ok = erqwest:req_async(default, self(), Ref=make_ref(), #{method => get, url => <<"https://httpbin.org/get">>}).
receive
    {erqwest_response, Ref, {ok, #{status := 200}}} -> ok
end.
```

[Docs](https://dlesl.github.io/erqwest/)
----

[Benchmarks](bench)
-------------------

Todo
----

* Shut down tokio event loop cleanly
* Test thoroughly
