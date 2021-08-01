%% test suite based on
%% https://github.com/puzza007/katipo/blob/master/test/katipo_SUITE.erl
%% but much less extensive

-module(erqwest_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

init_per_suite(Config) ->
  {ok, _} = application:ensure_all_started(erqwest),
  {ok, _} = application:ensure_all_started(erlexec),
  ok = erqwest:start_client(default),
  Config.

end_per_suite(_Config) ->
  ok = erqwest:stop_client(default),
  ok = application:stop(erqwest).

init_per_group(http, Config) ->
  Config;
init_per_group(client_cert, Config) ->
  {ok, #{status := 200, body := Cert}} =
    erqwest:get(default, <<"https://badssl.com/certs/badssl.com-client.p12">>),
  [ {cert, Cert}
  , {pass, <<"badssl.com">>}
  | Config
  ];
init_per_group(proxy, Config) ->
  case have_tinyproxy() of
    true -> Config;
    false -> {skipped, tinyproxy_not_found}
  end;
init_per_group(proxy_no_auth, Config) ->
  {Pid, Proxy} = start_tinyproxy([]),
  [ {tinyproxy, Pid}
  , {proxy, Proxy}
  | Config
  ];
init_per_group(proxy_auth, Config) ->
  {Pid, Proxy} = start_tinyproxy(["BasicAuth user password"]),
  [ {tinyproxy, Pid}
  , {proxy, Proxy}
  , {proxy_user, <<"user">>}
  , {proxy_password, <<"password">>}
  | Config
  ].

end_per_group(http, _Config) ->
  ok;
end_per_group(client_cert, _Config) ->
  ok;
end_per_group(proxy, _Config) ->
  ok;
end_per_group(proxy_no_auth, Config) ->
  stop_tinyproxy(?config(tinyproxy, Config));
end_per_group(proxy_auth, Config) ->
  stop_tinyproxy(?config(tinyproxy, Config)).

groups() ->
  [ {http, [parallel],
     [ get
     , get_http
     , post
     , timeout
     , connect
     , redirects
     ]}
  , {client_cert, [parallel],
     [ with_cert
     , without_cert
     ]}
  , {proxy, [],
     [ {group, proxy_no_auth}
     , {group, proxy_auth}
     ]}
  , {proxy_no_auth, [],
     [ proxy_get
     , proxy_system
     , proxy_no_proxy
     ]}
  , {proxy_auth, [],
     [ proxy_basic_auth
     ]}
  ].

all() ->
  [ {group, http}
  , {group, client_cert}
  , {group, proxy}
  ].

get(_Config) ->
  {ok, #{status := 200, body := Body}} =
    erqwest:get(default, <<"https://httpbin.org/get?a=%21%40%23%24%25%5E%26%2A%28%29_%2B">>),
  #{<<"args">> := #{<<"a">> := <<"!@#$%^&*()_+">>}} = jsx:decode(Body).

get_http(_Config) ->
  {ok, #{status := 200, body := Body}} =
    erqwest:get(default, <<"http://httpbin.org/get?a=%21%40%23%24%25%5E%26%2A%28%29_%2B">>),
  #{<<"args">> := #{<<"a">> := <<"!@#$%^&*()_+">>}} = jsx:decode(Body).

post(_Config) ->
  {ok, #{status := 200, body := Body}} =
    erqwest:post(default, <<"https://httpbin.org/post">>,
                 #{ headers => [{<<"Content-Type">>, <<"application/json">>}]
                  , body => <<"!@#$%^&*()">>}),
  #{<<"data">> := <<"!@#$%^&*()">>} = jsx:decode(Body).

timeout(_Config) ->
  {error, #{code := timeout}} =
    erqwest:get(default, <<"https://httpbin.org/delay/1">>, #{timeout => 500}).

connect(_Config) ->
  {error, #{code := connect}} =
    erqwest:get(default, <<"https://httpbin:12345">>).

redirects(_) ->
  {ok, #{status := 302}} =
    erqwest:get(erqwest:make_client(),
                <<"https://nghttp2.org/httpbin/redirect/6">>),
  {ok, #{status := 200}} =
    erqwest:get(erqwest:make_client(#{follow_redirects => true}),
                <<"https://nghttp2.org/httpbin/redirect/6">>),
  {error, #{code := redirect}} =
    erqwest:get(erqwest:make_client(#{follow_redirects => 5}),
                <<"https://nghttp2.org/httpbin/redirect/6">>).

with_cert(Config) ->
  C = erqwest:make_client(#{identity => {?config(cert, Config), ?config(pass, Config)}}),
  {ok, #{status := 200}} = erqwest:get(C, <<"https://client.badssl.com">>).

without_cert(_Config) ->
  C = erqwest:make_client(#{}),
  {ok, #{status := 400}} = erqwest:get(C, <<"https://client.badssl.com">>).

proxy_get(Config) ->
  LogSizeBefore = length(persistent_term:get(proxy_logs)),
  C = erqwest:make_client(#{proxy => [{all, #{url => ?config(proxy, Config)}}]}),
  {ok, #{status := 200}} = erqwest:get(C, <<"https://httpbin.org/get">>),
  timer:sleep(100), % wait for proxy logs to be collected
  true = length(persistent_term:get(proxy_logs)) > LogSizeBefore.

proxy_system(Config) ->
  LogSizeBefore = length(persistent_term:get(proxy_logs)),
  Fun =
    fun() ->
        C = erqwest:make_client(),
        {ok, #{status := 200}} = erqwest:get(C, <<"https://httpbin.org/get">>)
    end,
  eval_new_process(Fun, [{"HTTPS_PROXY", ?config(proxy, Config)}]),
  timer:sleep(100), % wait for proxy logs to be collected
  true = length(persistent_term:get(proxy_logs)) > LogSizeBefore.

proxy_no_proxy(Config) ->
  LogSizeBefore = length(persistent_term:get(proxy_logs)),
  Fun =
    fun() ->
        C = erqwest:make_client(#{proxy => no_proxy}),
        {ok, #{status := 200}} = erqwest:get(C, <<"https://httpbin.org/get">>)
    end,
  eval_new_process(Fun, [{"HTTPS_PROXY", ?config(proxy, Config)}]),
  timer:sleep(100), % wait for proxy logs to be collected
  false = length(persistent_term:get(proxy_logs)) > LogSizeBefore.

proxy_basic_auth(Config) ->
  C0 = erqwest:make_client(#{proxy => [{https, #{url => ?config(proxy, Config)}}]}),
  {error, #{code := connect}} = erqwest:get(C0, <<"https://httpbin.org/get">>),
  C1 = erqwest:make_client(#{proxy => [{https, #{ url => ?config(proxy, Config)
                                                , basic_auth =>
                                                    {?config(proxy_user, Config),
                                                     ?config(proxy_password, Config)}
                                                }}]}),
  {ok, #{status := 200}} = erqwest:get(C1, <<"https://httpbin.org/get">>).

%% helpers

have_tinyproxy() ->
  case exec:run("which tinyproxy", [sync]) of
    {ok, _} -> true;
    {error, _}-> false
  end.

start_tinyproxy(ConfigLines0) ->
  ConfigLines = ["Listen 127.0.0.1", "Port 8888"] ++ ConfigLines0 ++ [""],
  ok = file:write_file("tinyproxy.conf", lists:join($\n, ConfigLines)),
  persistent_term:put(proxy_logs, []),
  Log = fun(S, _, D) ->
            ct:log("tinyproxy ~w: ~s", [S, D]),
            persistent_term:put(proxy_logs, persistent_term:get(proxy_logs) ++ [D])
        end,
  {ok, _, Pid} = exec:run("tinyproxy -d -c tinyproxy.conf", [{stdout, Log}, {stderr, Log}]),
  {Pid, <<"http://127.0.0.1:8888">>}.

stop_tinyproxy(Pid) ->
  ok = exec:stop(Pid),
  persistent_term:erase(proxy_logs),
  ok = file:delete("tinyproxy.conf").

%% reqwest caches the proxy env vars, so we need a new process
eval_new_process(Fun, Env) ->
  CodePath = lists:join($ , [P || P <- code:get_path(), not lists:prefix(code:root_dir(), P)]),
  Term = base64:encode(term_to_binary(Fun)),
  Cmd = io_lib:format(
          "erl -pa ~s -noshell -eval '(binary_to_term(base64:decode(<<\"~s\">>)))(), init:stop(0).'",
          [CodePath, Term]
         ),
  {ok, _} = exec:run(iolist_to_binary(Cmd), [sync, {env, Env}, {stdout, print}, {stderr, print}]).
