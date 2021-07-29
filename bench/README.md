Benchmarks
----------

    $ make start-nginx
    $ make bench


Results
-------

Disclaimer: I haven't put any effort into optimising pool sizes or number of
workers or anything else really. It would probably be better to get it working
with [httpc_bench](https://github.com/lpgauth/httpc_bench). Hackney might also
be at a disadvantage for the TLS benchmark, since it doesn't support HTTP2.

Run on an Intel(R) Core(TM) i5-6260U CPU @ 1.80GHz

```
=== Benchmarking erqwest, no TLS, 50 workers ===
876437 requests succeeded in 30005 ms, 29209.698384 r/s
=== Benchmarking erqwest, TLS, 50 workers ===
616762 requests succeeded in 30001 ms, 20558.048065 r/s
```

```
=== Benchmarking katipo, no TLS, 50 workers ===
470342 requests succeeded in 30003 ms, 15676.499017 r/s
=== Benchmarking katipo, TLS, 50 workers ===
278470 requests succeeded in 30005 ms, 9280.786536 r/s
```

```
=== Benchmarking hackney, no TLS, 50 workers ===
178715 requests succeeded in 30006 ms, 5955.975472 r/s
=== Benchmarking hackney, TLS, 50 workers ===
<snip a whole bunch of no-ssl-verification warnings>>
132771 requests succeeded in 30007 ms, 4424.667578 r/s
```

