%% test suite based on
%% https://github.com/puzza007/katipo/blob/master/test/katipo_SUITE.erl
%% but much less extensive

-module(erqwest_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

suite() ->
  [{timetrap, {seconds, 60}}].

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
init_per_group(cookies, Config) ->
  Config;
init_per_group(async, Config) ->
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
  ];
init_per_group(runtime, Config) ->
  application:stop(erqwest),
  Config.

end_per_group(http, _Config) ->
  ok;
end_per_group(cookies, _Config) ->
  ok;
end_per_group(async, _Config) ->
  ok;
end_per_group(client_cert, _Config) ->
  ok;
end_per_group(proxy, _Config) ->
  ok;
end_per_group(proxy_no_auth, Config) ->
  stop_tinyproxy(?config(tinyproxy, Config));
end_per_group(proxy_auth, Config) ->
  stop_tinyproxy(?config(tinyproxy, Config));
end_per_group(runtime, _Config) ->
  ok = application:start(erqwest).

groups() ->
  [ {http, [parallel],
     [ get
     , get_http
     , https_only
     , post
     , timeout
     , timeout_default
     , timeout_infinity
     , connect
     , redirect_follow
     , redirect_no_follow
     , redirect_limited
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
  , {cookies, [parallel],
     [ cookies_enabled
     , cookies_disabled
     , cookies_default
     ]}
  , {async, [parallel],
     [ async_get
     , async_cancel
     , async_cancel_after_response
     , async_race_requests
     ]}
  , {runtime, [],
     [ runtime_stopped_make_client
     , runtime_stopped_inflight_request
     , runtime_stopped_new_request
     , runtime_unexpected_exit
     , runtime_multiple_runtimes
     ]}
  ].

all() ->
  [ {group, http}
  , {group, client_cert}
  , {group, proxy}
  , {group, cookies}
  , {group, async}
  , {group, runtime}
  ].

get(_Config) ->
  {ok, #{status := 200, body := Body}} =
    erqwest:get(default, <<"https://httpbin.org/get?a=%21%40%23%24%25%5E%26%2A%28%29_%2B">>),
  #{<<"args">> := #{<<"a">> := <<"!@#$%^&*()_+">>}} = jsx:decode(Body).

get_http(_Config) ->
  {ok, #{status := 200, body := Body}} =
    erqwest:get(default, <<"http://httpbin.org/get?a=%21%40%23%24%25%5E%26%2A%28%29_%2B">>),
  #{<<"args">> := #{<<"a">> := <<"!@#$%^&*()_+">>}} = jsx:decode(Body).

https_only(_Config) ->
  C = erqwest:make_client(#{https_only => true}),
  {error, #{code := unknown}} =
    erqwest:get(C, <<"http://httpbin.org/get">>).

post(_Config) ->
  {ok, #{status := 200, body := Body}} =
    erqwest:post(default, <<"https://httpbin.org/post">>,
                 #{ headers => [{<<"Content-Type">>, <<"application/json">>}]
                  , body => <<"!@#$%^&*()">>}),
  #{<<"data">> := <<"!@#$%^&*()">>} = jsx:decode(Body).

timeout(_Config) ->
  {error, #{code := timeout}} =
    erqwest:get(default, <<"https://httpbin.org/delay/1">>, #{timeout => 500}).

timeout_infinity(_Config) ->
  {ok, #{status := 200}} =
    erqwest:get(default, <<"https://httpbin.org/delay/1">>, #{timeout => infinity}).

timeout_default(_Config) ->
  {ok, #{status := 200}} =
    erqwest:get(default, <<"https://httpbin.org/delay/1">>).

connect(_Config) ->
  {error, #{code := connect}} =
    erqwest:get(default, <<"https://httpbin:12345">>).

redirect_follow(_Config) ->
  {ok, #{status := 200}} =
    erqwest:get(default,
                <<"https://nghttp2.org/httpbin/redirect/3">>).

redirect_no_follow(_Config) ->
  {ok, #{status := 302}} =
    erqwest:get(erqwest:make_client(#{follow_redirects => false}),
                <<"https://nghttp2.org/httpbin/redirect/3">>).

redirect_limited(_Config) ->
  {error, #{code := redirect}} =
    erqwest:get(erqwest:make_client(#{follow_redirects => 2}),
                <<"https://nghttp2.org/httpbin/redirect/3">>).

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
        {ok, _} = application:ensure_all_started(erqwest),
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
        {ok, _} = application:ensure_all_started(erqwest),
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

cookies_enabled(_Config) ->
  C0 = erqwest:make_client(#{cookie_store => true}),
  {ok, #{status := 200, body := Body}} = erqwest:get(C0, <<"https://httpbin.org/cookies/set/test_cname/test_cvalue">>),
  #{<<"cookies">> := #{<<"test_cname">> := <<"test_cvalue">>}} = jsx:decode(Body).

cookies_disabled(_Config) ->
  C0 = erqwest:make_client(#{cookie_store => false}),
  {ok, #{status := 200, body := Body}} = erqwest:get(C0, <<"https://httpbin.org/cookies/set/test_cname/test_cvalue">>),
  Cookies = #{},
  #{<<"cookies">> := Cookies} = jsx:decode(Body).

cookies_default(_Config) ->
  C0 = erqwest:make_client(),
  {ok, #{status := 200, body := Body}} = erqwest:get(C0, <<"https://httpbin.org/cookies/set/test_cname/test_cvalue">>),
  Cookies = #{},
  #{<<"cookies">> := Cookies} = jsx:decode(Body).

async_get(_Config) ->
  erqwest:req_async(default, self(), Ref=make_ref(), #{method => get, url => <<"https://httpbin.org/get">>}),
  receive
    {erqwest_response, Ref, Res} ->
      {ok, #{status := 200}} = Res
  end.

async_cancel(_Config) ->
  Handle =
    erqwest:req_async(default, self(), Ref=make_ref(), #{method => get, url => <<"https://httpbin.org/delay/1">>}),
  ok = erqwest:cancel(Handle),
  receive
    {erqwest_response, Ref, Res} ->
      {error, #{code := cancelled}} = Res
  end,
  %% cancelling again has no effect
  ok = erqwest:cancel(Handle).

async_cancel_after_response(_Config) ->
  Handle =
    erqwest:req_async(default, self(), Ref=make_ref(), #{method => get, url => <<"https://httpbin.org/get">>}),
  receive
    {erqwest_response, Ref, Res} ->
      {ok, #{status := 200}} = Res
  end,
  ok = erqwest:cancel(Handle),
  receive
    {erqwest_response, _, _} ->
      ct:fail(unexpected_response)
  after 100 ->
      ok
  end.

async_race_requests(_Config) ->
  Refs0 =
    lists:map(
      fun(Delay) ->
          Url = <<"https://httpbin.org/delay/", (integer_to_binary(Delay))/binary>>,
          Handle = erqwest:req_async(default, self(), Ref=make_ref(), #{method => get, url => Url}),
          {Ref, {Handle, Delay}}
      end,
      [1, 5, 5, 5]
     ),
  Refs = maps:from_list(Refs0),
  receive
    {erqwest_response, FirstRef, FirstRes} ->
      #{FirstRef := {_, 1}} = Refs,
      [erqwest:cancel(H) || {H, _} <- maps:values(Refs)],
      {ok, #{status := 200}} = FirstRes
  end,
  Rest = [receive {erqwest_response, R, Res} -> Res end
          || R <- maps:keys(Refs), R =/= FirstRef],
  [{error, #{code := cancelled}} = Res || Res <- Rest].

runtime_stopped_make_client(_Config) ->
  ok = application:start(erqwest),
  erqwest:make_client(),
  ok = application:stop(erqwest),
  ?assertException(error, badarg, erqwest:make_client()).

runtime_stopped_inflight_request(_Config) ->
  ok = application:start(erqwest),
  C = erqwest:make_client(),
  %% two requests that will hopefully be at different stages
  erqwest:req_async(C, self(), Ref0=make_ref(), #{method => get, url => <<"https://httpbin.org/delay/5">>}),
  timer:sleep(1000),
  erqwest:req_async(C, self(), Ref1=make_ref(), #{method => get, url => <<"https://httpbin.org/delay/5">>}),
  ok = application:stop(erqwest),
  receive
    {erqwest_response, Ref0, Resp0} ->
      %% the error could vary depending on what stage the connection was at
      {error, #{}} = Resp0
  end,
  receive
    {erqwest_response, Ref1, Resp1} ->
      {error, #{}} = Resp1
  end.

runtime_stopped_new_request(_Config) ->
  ok = application:start(erqwest),
  C = erqwest:make_client(),
  ok = application:stop(erqwest),
  ?assertException(error, bad_runtime, erqwest:get(C, <<"https://httpbin.org/get">>)).

runtime_unexpected_exit(_Config) ->
  process_flag(trap_exit, true),
  {ok, Pid} = erqwest_runtime:start_link(),
  erqwest:stop_runtime(erqwest_runtime:get()),
  receive
    {'EXIT', Pid, erqwest_runtime_failure} -> ok
  end.

runtime_multiple_runtimes(_Config) ->
  process_flag(trap_exit, true),
  {ok, Pid1} = erqwest_runtime:start_link(),
  C1 = erqwest:make_client(),
  E1 = erqwest_runtime:get(),
  %% brutally kill the gen_server so it doesn't stop the runtime. As long as we
  %% have a live reference to the runtime it won't be GC'd.
  exit(Pid1, kill),
  receive
    {'EXIT', Pid1, killed} -> ok
  end,
  {ok, Pid2} = erqwest_runtime:start_link(),
  C2 = erqwest:make_client(),
  {ok, _} = erqwest:get(C1, <<"https://httpbin.org/get">>),
  {ok, _} = erqwest:get(C2, <<"https://httpbin.org/get">>),
  erqwest:stop_runtime(E1),
  ok = gen_server:stop(Pid2).

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
  wait_for_port({127, 0, 0, 1}, 8888),
  {Pid, <<"http://127.0.0.1:8888">>}.

wait_for_port(Address, Port) ->
  case gen_tcp:connect(Address, Port, []) of
    {ok, Socket} ->
      gen_tcp:close(Socket),
      timer:sleep(100); % let the log messages come through
    {error, _} ->
      timer:sleep(100),
      wait_for_port(Address, Port)
  end.

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
