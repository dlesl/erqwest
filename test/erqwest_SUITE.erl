%% test suite based on
%% https://github.com/puzza007/katipo/blob/master/test/katipo_SUITE.erl
%% but much less extensive

-module(erqwest_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

suite() ->
  [{timetrap, {seconds, 30}}].

init_per_suite(Config) ->
  {ok, _} = application:ensure_all_started(erqwest),
  {ok, _} = application:ensure_all_started(erlexec),
  ok = erqwest:start_client(default),
  Config.

end_per_suite(_Config) ->
  ok = erqwest:stop_client(default),
  ok = application:stop(erqwest).

init_per_group(cookies, Config) ->
  case erqwest:feature(cookies) of
    true -> Config;
    false -> {skipped, cookies_not_enabled}
  end;
init_per_group(gzip, Config) ->
  case erqwest:feature(gzip) of
    true -> Config;
    false -> {skipped, gzip_not_enabled}
  end;
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
  Config;
init_per_group(_Group, Config) ->
  Config.

end_per_group(proxy_no_auth, Config) ->
  stop_tinyproxy(?config(tinyproxy, Config));
end_per_group(proxy_auth, Config) ->
  stop_tinyproxy(?config(tinyproxy, Config));
end_per_group(runtime, _Config) ->
  ok = application:start(erqwest),
  ok = erqwest:start_client(default);
end_per_group(_Group, _Config) ->
  ok.

init_per_testcase(_Case, Config) ->
  Config.

end_per_testcase(time_nifs, _Config) ->
  %% this test generates a lot of stray messages
  ok;
end_per_testcase(Case, _Config) ->
  receive
    Msg -> ct:fail("stray message detected after ~p: ~p", [Case, Msg])
  after 100 ->
      ok
  end.

groups() ->
  [ {http, [parallel],
     [ get
     , get_http
     , https_only
     , post
     , post_iolist
     , timeout
     , timeout_default
     , timeout_infinity
     , connect
     , redirect_follow
     , redirect_no_follow
     , redirect_limited
     , kill_process
     , bad_header_key
     , bad_header_value
     , bad_url
     , bad_body
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
  , {gzip, [parallel],
     [ gzip_enabled
     , gzip_disabled
     ]}
  , {stream, [parallel],
     [ stream_request_success
     , stream_request_early_reply
     , stream_response_success
     , stream_both_success
     , stream_request_invalid
     , stream_request_closed
     , stream_request_backpressure
     , stream_response_closed
     , stream_request_cancel
     , stream_response_cancel
     , stream_wrong_process
     , stream_async_success
     , stream_async_cancel_connect
     , stream_async_cancel_send
     , stream_async_cancel_send_blocked
     , stream_async_cancel_finish_send
     , stream_async_cancel_read
     , stream_connect_timeout
     , stream_response_timeout
     , stream_handle_dropped_send
     ]}
  , {time_nifs, [{repeat, 5}],
     [ time_nifs
     ]}
  ].

all() ->
  [ {group, http}
  , {group, client_cert}
  , {group, proxy}
  , {group, cookies}
  , {group, async}
  , {group, runtime}
  , {group, gzip}
  , {group, stream}
  , {group, time_nifs}
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

post_iolist(_Config) ->
  {ok, #{status := 200, body := Body}} =
    erqwest:post(default, <<"https://httpbin.org/post">>,
                 #{ body => [$I, " am an ", <<"iolist">>, [[$.]]]}),
  #{<<"data">> := <<"I am an iolist.">>} = jsx:decode(Body).

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

kill_process(_Config) ->
  %% If the process executing a synchronouse request is killed, the request
  %% should be cancelled. TODO: add monitor support to rustler.
  ok.
%% process_flag(trap_exit, true),
%% {LSock, Url} = server:listen(),
%% Pid = spawn_link(fun() -> erqwest:get(default, Url) end),
%% Sock = server:accept(LSock),
%% server:read(Sock),
%% exit(Pid, kill),
%% receive {'EXIT', Pid, killed} -> ok end,
%% server:wait_for_close(Sock).

bad_header_key(_Config) ->
  {error, #{code := request}} =
    erqwest:get(default, <<"https://httpbin.org/get">>,
                #{headers => [{<<"ånej, latin-1!">>, <<"value">>}]}).

bad_header_value(_Config) ->
  {ok, _} = erqwest:get(default, <<"https://httpbin.org/get">>,
                        #{headers => [{<<"name">>, <<"latin-1 tillåts här">>}]}),
  {error, #{code := request}} =
    erqwest:get(default, <<"https://httpbin.org/get">>,
                #{headers => [{<<"name">>, <<"byte ", 127, " isn't allowed">>}]}).

bad_url(_Config) ->
  {ok, _} = erqwest:get(default, <<"https://httpbin.org/get?q=🌐"/utf8>>),
  {error, #{code := url}} = erqwest:get(default, <<"https://httpbin.org/get?q=nä">>),
  {error, #{code := url}} = erqwest:get(default, <<"not even trying">>).

-dialyzer({nowarn_function, bad_body/1}).
bad_body(_Config) ->
  {error, #{code := request}} =
    erqwest:post(default, <<"https://httpbin.org/post">>,
                 #{body => [<<"this">>, is_not_iodata]}).

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
  erqwest_async:req(default, self(), Ref=make_ref(), #{method => get, url => <<"https://httpbin.org/get">>}),
  receive
    {erqwest_response, Ref, reply, Res} ->
      #{status := 200} = Res
  end.

async_cancel(_Config) ->
  Handle =
    erqwest_async:req(default, self(), Ref=make_ref(), #{method => get, url => <<"https://httpbin.org/delay/1">>}),
  ok = erqwest_async:cancel(Handle),
  receive
    {erqwest_response, Ref, error, Res} ->
      #{code := cancelled} = Res
  end,
  %% cancelling again has no effect
  ok = erqwest_async:cancel(Handle).

async_cancel_after_response(_Config) ->
  Handle =
    erqwest_async:req(default, self(), Ref=make_ref(), #{method => get, url => <<"https://httpbin.org/get">>}),
  receive
    {erqwest_response, Ref, reply, Res} ->
      #{status := 200} = Res
  end,
  ok = erqwest_async:cancel(Handle),
  receive
    {erqwest_response, _, _, _} ->
      ct:fail(unexpected_response)
  after 100 ->
      ok
  end.

async_race_requests(_Config) ->
  Refs0 =
    lists:map(
      fun(Delay) ->
          Url = <<"https://httpbin.org/delay/", (integer_to_binary(Delay))/binary>>,
          Handle = erqwest_async:req(default, self(), Ref=make_ref(), #{method => get, url => Url}),
          {Ref, {Handle, Delay}}
      end,
      [1, 5, 5, 5]
     ),
  Refs = maps:from_list(Refs0),
  receive
    {erqwest_response, FirstRef, reply, FirstRes} ->
      #{status := 200} = FirstRes,
      #{FirstRef := {_, 1}} = Refs,
      [erqwest_async:cancel(H) || {H, _} <- maps:values(Refs)]
  end,
  Rest = [receive {erqwest_response, R, error, Res} -> Res end
          || R <- maps:keys(Refs), R =/= FirstRef],
  [#{code := cancelled} = Res || Res <- Rest].

runtime_stopped_make_client(_Config) ->
  ok = application:start(erqwest),
  erqwest:make_client(),
  ok = application:stop(erqwest),
  ?assertException(error, badarg, erqwest:make_client()).

runtime_stopped_inflight_request(_Config) ->
  ok = application:start(erqwest),
  C = erqwest:make_client(),
  %% two requests that will hopefully be at different stages
  erqwest_async:req(C, self(), Ref0=make_ref(), #{method => get, url => <<"https://httpbin.org/delay/5">>}),
  timer:sleep(1000),
  erqwest_async:req(C, self(), Ref1=make_ref(), #{method => get, url => <<"https://httpbin.org/delay/5">>}),
  ok = application:stop(erqwest),
  receive
    {erqwest_response, Ref0, error, _} ->
      %% the error could vary depending on what stage the connection was at
      ok
  end,
  receive
    {erqwest_response, Ref1, error, _} ->
      ok
  end.

runtime_stopped_new_request(_Config) ->
  ok = application:start(erqwest),
  C = erqwest:make_client(),
  ok = application:stop(erqwest),
  ?assertException(error, bad_runtime, erqwest:get(C, <<"https://httpbin.org/get">>)).

runtime_unexpected_exit(_Config) ->
  process_flag(trap_exit, true),
  {ok, Pid} = erqwest_runtime:start_link(),
  erqwest_nif:stop_runtime(erqwest_runtime:get()),
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
  erqwest_nif:stop_runtime(E1),
  unlink(Pid2),
  ok = gen_server:stop(Pid2).

gzip_enabled(_Config) ->
  {ok, #{status := 200, body := Body}} = erqwest:get(default, <<"https://httpbin.org/gzip">>),
  #{<<"gzipped">> := true} = jsx:decode(Body).

gzip_disabled(_Config) ->
  C = erqwest:make_client(#{gzip => false}),
  {ok, #{status := 200, body := Body}} = erqwest:get(C, <<"https://httpbin.org/gzip">>),
  #{<<"gzipped">> := true} = jsx:decode(zlib:gunzip(Body)).

stream_request_success(_Config) ->
  {handle, Handle} = erqwest:req(default, #{ method => post
                                           , url => <<"https://httpbin.org/post">>
                                           , body => stream
                                           }),
  ok = erqwest:send(Handle, <<"1,">>),
  ok = erqwest:send(Handle, <<"2,">>),
  ok = erqwest:send(Handle, <<"3">>),
  {ok, #{body := Body}} = erqwest:finish_send(Handle),
  #{<<"data">> := <<"1,2,3">>} = jsx:decode(Body).

stream_request_early_reply(_Config) ->
  {LSock, Url} = server:listen(),
  {handle, Handle} = erqwest:req(default, #{ method => post
                                           , url => Url
                                           , body => stream
                                           }),
  Sock = server:accept(LSock),
  ok = erqwest:send(Handle, <<"data">>),
  server:read(Sock),
  server:reply(Sock, [<<"content-length: 0">>]),
  timer:sleep(100),
  {reply, #{body := <<>>}} = erqwest:send(Handle, <<"more data">>).

stream_response_success(_Config) ->
  {ok, #{body := Handle}} =
    erqwest:get(default, <<"https://httpbin.org/stream-bytes/10000">>, #{response_body => stream}),
  Loop = fun F() ->
             Res = erqwest:read(Handle, #{length => 100}),
             case Res of
               {ok, Data} ->
                 ct:log("done"),
                 [Data];
               {more, Data} ->
                 ct:log("more"),
                 [Data|F()]
             end
         end,
  Data = Loop(),
  ?assertEqual(iolist_size(Data), 10000),
  ?assertException(error, badarg, erqwest:read(Handle)).

stream_both_success(_Config) ->
  {LSock, Url} = server:listen(),
  {handle, H} = erqwest:post(default, Url, #{body => stream, response_body => stream}),
  Sock = server:accept(LSock),
  server:read(Sock),
  ok = erqwest:send(H, <<"Data">>),
  server:reply(Sock, []),
  {ok, #{body := H}} = erqwest:finish_send(H),
  ?assertException(error, badarg, erqwest:send(H, <<"fail">>)),
  ?assertException(error, badarg, erqwest:finish_send(H)),
  server:send(Sock, <<"Data">>),
  {more, <<"Data">>} = erqwest:read(H, #{length => 4, period => 100}),
  server:close(Sock),
  {ok, <<>>} = erqwest:read(H),
  ?assertException(error, badarg, erqwest:read(H)).

stream_request_invalid(_Config) ->
  {error, #{code := url}} = erqwest:post(default, <<"invalid">>, #{body => stream}).

stream_request_backpressure(_Config) ->
  {LSock, Url} = server:listen(),
  H = erqwest_async:req(default, self(), Ref=make_ref(), #{ method => post
                                                          , url => Url
                                                          , body => stream
                                                          }),

  receive {erqwest_response, Ref, next} -> ok end,
  BytesSent = send_until_blocked(H, Ref),
  Sock = server:accept(LSock),
  server:read_silent(Sock, BytesSent),
  %% now we can send again
  ?assert(send_until_blocked(H, Ref) > 0),
  server:close(Sock),
  receive {erqwest_response, Ref, error, _} -> ok end.

stream_request_closed(_Config) ->
  {LSock, Url} = server:listen(),
  {handle, H} = erqwest:post(default, Url, #{body => stream}),
  server:close(server:accept(LSock)),
  timer:sleep(100),
  {error, #{code := request}} = erqwest:send(H, <<"more">>),
  ?assertException(error, badarg, erqwest:send(H, <<"fail">>)).

stream_request_cancel(_Config) ->
  {LSock, Url} = server:listen(),
  {handle, H} = erqwest:post(default, Url, #{body => stream}),
  Sock = server:accept(LSock),
  server:read(Sock),
  ok = erqwest:send(H, <<"begin">>),
  ok = erqwest:send(H, <<"please">>),
  server:read(Sock),
  erqwest:cancel(H),
  server:wait_for_close(Sock),
  ?assertException(error, badarg, erqwest:send(H, <<"fail">>)).

stream_response_closed(_Config) ->
  {LSock, Url} = server:listen(),
  Parent = self(),
  spawn_link(fun() ->
                 Sock = server:accept(LSock),
                 server:read(Sock),
                 server:reply(Sock, [<<"content-length: 100">>]),
                 ok = gen_tcp:controlling_process(Sock, Parent),
                 Parent ! Sock
             end),
  {ok, #{body := H}} = erqwest:post(default, Url, #{response_body => stream}),
  receive Sock -> Sock end,
  server:send(Sock, <<"data">>),
  {more, <<"data">>} = erqwest:read(H, #{length => 4, period => 100}),
  server:close(Sock),
  {error, #{code := body}} = erqwest:read(H),
  ?assertException(error, badarg, erqwest:read(H)).

stream_response_cancel(_Config) ->
  {LSock, Url} = server:listen(),
  Parent = self(),
  spawn_link(fun() ->
                 Sock = server:accept(LSock),
                 server:read(Sock),
                 server:reply(Sock, [<<"content-length: 100">>]),
                 ok = gen_tcp:controlling_process(Sock, Parent),
                 Parent ! Sock
             end),
  {ok, #{body := H}} = erqwest:post(default, Url, #{response_body => stream}),
  receive Sock -> Sock end,
  server:send(Sock, <<"data">>),
  {more, <<"data">>} = erqwest:read(H, #{length => 4, period => 100}),
  erqwest:cancel(H),
  server:wait_for_close(Sock),
  ?assertException(error, badarg, erqwest:read(H)).

stream_wrong_process(_Config) ->
  Self = self(),
  {_, Url} = server:listen(),
  spawn_link(fun() ->
                 {handle, Handle} =
                   erqwest:post(default, Url,
                                #{body => stream, response_body => stream}),
                 Self ! Handle
             end),
  receive Handle -> Handle end,
  ?assertException(error, {assertEqual, _}, erqwest:send(Handle, <<"data">>)),
  ?assertException(error, {assertEqual, _}, erqwest:finish_send(Handle)),
  ?assertException(error, {assertEqual, _}, erqwest:finish_send(Handle)),
  ?assertException(error, {assertEqual, _}, erqwest:read(Handle)).

stream_async_success(_Config) ->
  Data = << <<B>> || <<B>> <= rand:bytes(10000), B >= 32, B =< 126 >>,
  <<Data1:(size(Data) div 2)/binary, Data2/binary>> = Data,
  Handle = erqwest_async:req(default, self(), Ref=make_ref(),
                             #{ method => post
                              , url => <<"https://httpbin.org/post">>
                              , body => stream
                              , response_body => stream
                              }),
  receive {erqwest_response, Ref, next} -> ok end,
  ok = erqwest_async:send(Handle, Data1),
  receive {erqwest_response, Ref, next} -> ok end,
  ok = erqwest_async:send(Handle, Data2),
  receive {erqwest_response, Ref, next} -> ok end,
  ok = erqwest_async:finish_send(Handle),
  receive {erqwest_response, Ref, reply, Payload} -> ok end,
  ?assert(not is_map_key(body, Payload)),
  Loop = fun Loop() ->
             ok = erqwest_async:read(Handle, #{length => 1}),
             receive
               {erqwest_response, Ref, chunk, Chunk} ->
                 [Chunk|Loop()];
               {erqwest_response, Ref, fin, Chunk} ->
                 [Chunk]
             end
         end,
  #{<<"data">> := Data} = jsx:decode(iolist_to_binary(Loop())).

stream_async_cancel_connect(_Config) ->
  {_, Url} = server:listen(),
  Handle = erqwest_async:req(default, self(), Ref=make_ref(),
                             #{ method => post
                              , url => Url
                              , body => stream
                              , response_body => stream
                              }),
  receive {erqwest_response, Ref, next} -> ok end,
  ok = erqwest_async:cancel(Handle),
  receive
    {erqwest_response, Ref, error, Err} ->
      #{code := cancelled} = Err
  end.

stream_async_cancel_send(_Config) ->
  {LSock, Url} = server:listen(),
  Handle = erqwest_async:req(default, self(), Ref=make_ref(),
                             #{ method => post
                              , url => Url
                              , body => stream
                              , response_body => stream
                              }),
  receive {erqwest_response, Ref, next} -> ok end,
  _Sock = server:accept(LSock),
  timer:sleep(100),
  ok = erqwest_async:send(Handle, <<"data">>),
  ok = erqwest_async:cancel(Handle),
  %% we might get a `next` before our `error`
  receive
    {erqwest_response, Ref, error, Err} ->
      ok;
    {erqwest_response, Ref, next} ->
      receive
        {erqwest_response, Ref, error, Err} -> ok
      end
  end,
  #{code := cancelled} = Err.

stream_async_cancel_send_blocked(_Config) ->
  {LSock, Url} = server:listen(),
  Handle = erqwest_async:req(default, self(), Ref=make_ref(),
                             #{ method => post
                              , url => Url
                              , body => stream
                              , response_body => stream
                              }),
  receive {erqwest_response, Ref, next} -> ok end,
  _Sock = server:accept(LSock),
  send_until_blocked(Handle, Ref),
  ok = erqwest_async:cancel(Handle),
  receive {erqwest_response, Ref, error, Err} -> ok end,
  #{code := cancelled} = Err.

stream_async_cancel_finish_send(_Config) ->
  {LSock, Url} = server:listen(),
  Handle = erqwest_async:req(default, self(), Ref=make_ref(),
                             #{ method => post
                              , url => Url
                              , body => stream
                              , response_body => stream
                              }),
  receive {erqwest_response, Ref, next} -> ok end,
  _Sock = server:accept(LSock),
  ok = erqwest_async:finish_send(Handle),
  ok = erqwest_async:cancel(Handle),
  receive {erqwest_response, Ref, error, Err} -> ok end,
  #{code := cancelled} = Err.

stream_async_cancel_read(_Config) ->
  {LSock, Url} = server:listen(),
  Handle = erqwest_async:req(default, self(), Ref=make_ref(),
                             #{ method => post
                              , url => Url
                              , body => stream
                              , response_body => stream
                              }),
  receive {erqwest_response, Ref, next} -> ok end,
  Sock = server:accept(LSock),
  ok = erqwest_async:finish_send(Handle),
  server:read(Sock),
  server:reply(Sock, []),
  receive {erqwest_response, Ref, reply, _} -> ok end,
  ok = erqwest_async:cancel(Handle),
  receive {erqwest_response, Ref, error, Err} -> ok end,
  #{code := cancelled} = Err.

stream_connect_timeout(_Config) ->
  {_LSock, Url} = server:listen(),
  {handle, H} = erqwest:get(default, Url, #{timeout => 10, body => stream}),
  timer:sleep(100),
  {error, #{code := timeout}} = erqwest:send(H, <<"data">>).

stream_response_timeout(_Config) ->
  {skip, "reqwest behaviour has changed, maybe buffer size?"}.
  %% {ok, #{status := 200, body := H}} =
  %%   erqwest:get(default, <<"https://httpbin.org/drip">>,
  %%               #{timeout => 1000, response_body => stream}),
  %% {error, #{code := timeout}} = erqwest:read(H).

stream_handle_dropped_send(_Config) ->
  %% If the ReqHandle is GC'd before finish_send has been called, we need to
  %% ensure we do not indicate to the server that the request body is complete.
  {LSock, Url} = server:listen(),
  Sock = (fun() ->
              {handle, _} = erqwest:post(default, Url, #{body => stream}),
              Sock = server:accept(LSock),
              Sock
          end)(),
  erlang:garbage_collect(),
  Data = server:wait_for_close(Sock),
  %% final chunk is indicated by 0\r\n\r\n
  nomatch = string:find(Data, <<"0\r\n\r\n">>).


%% This test case doesn't fail, it's just for the logs. You probably want to run
%% it with a release build of the NIF.

-define(timed(Fun), (fun() -> {Time, Res} = timer:tc(Fun),
                              ct:log("~s took ~B µs", [??Fun, Time]),
                              Res
                     end)()).

time_nifs(_Config) ->
  ?timed(fun() -> erqwest_nif:feature(cookies) end),
  Runtime = ?timed(fun() -> erqwest_nif:start_runtime(self()) end),
  Client = ?timed(fun() -> erqwest_nif:make_client(Runtime, #{}) end),
  ?timed(fun() ->
             erqwest_nif:req(Client, self(), no_ref,
                             #{ method => get
                              , url => <<"invalid">>
                              })
         end),
  BigBody = binary:copy(<<0>>, 1024 * 1024),
  ?timed(fun() ->
             erqwest_nif:req(Client, self(), no_ref,
                             #{ method => post
                              , url => <<"invalid">>
                              , body => BigBody
                              })
         end),
  ManyHeaders =
    [{<<"test">>,
      <<"the quick brown fox jumped over the lazy dog and a 64 byte-long binary ",
        (integer_to_binary(I))/binary>>}
     || I <- lists:seq(1, 100)],
  ?timed(fun() ->
             erqwest_nif:req(Client, self(), no_ref,
                             #{ method => post
                              , url => <<"invalid">>
                              , headers => ManyHeaders
                              })
         end),
  WithHandle =
    fun(WrappedFun) ->
        Ref = make_ref(),
        Self = self(),
        {LSock, Url} = server:listen(),
        Handle = ?timed(fun() ->
                            erqwest_nif:req(Client, Self, Ref,
                                            #{ method => post
                                             , url => Url
                                             , body => stream
                                             , response_body => stream
                                             })
                        end),
        receive {erqwest_response, Ref, next} -> ok end,
        Sock = server:accept(LSock),
        server:read(Sock),
        ReplyFun = fun() -> server:reply(Sock, []) end,
        WrappedFun(Handle, Ref, ReplyFun)
    end,
  WithHandle(fun(Handle, _, _) ->
                 ?timed(fun() -> erqwest_nif:send(Handle, BigBody) end)
             end),
  WithHandle(fun(Handle, _, _) ->
                 ?timed(fun() -> erqwest_nif:finish_send(Handle) end)
             end),
  WithHandle(fun(Handle, _, _) ->
                 ?timed(fun() -> erqwest_nif:cancel_stream(Handle) end)
             end),
  WithHandle(fun(Handle, _, _) ->
                 ?timed(fun() -> erqwest_nif:cancel(Handle) end)
             end),
  WithHandle(fun(Handle, Ref, ReplyFun) ->
                 ?timed(fun() -> erqwest_nif:finish_send(Handle) end),
                 ReplyFun(),
                 receive {erqwest_response, Ref, reply, _} -> ok end,
                 ?timed(fun() -> erqwest_nif:read(Handle, #{period => 0}) end)
             end),
  ?timed(fun() -> erqwest_nif:close_client(Client) end),
  ?timed(fun() -> erqwest_nif:stop_runtime(Runtime) end).

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

send_until_blocked(AsyncHandle, Ref) ->
  Data = list_to_binary([0 || _ <- lists:seq(1, 1000)]),
  send_until_blocked(AsyncHandle, Ref, Data, 0).

send_until_blocked(AsyncHandle, Ref, Data, Sent) ->
  ?assert(Sent < 100 * 1024 * 1024),
  erqwest_async:send(AsyncHandle, Data),
  receive
    {erqwest_response, Ref, next} ->
      send_until_blocked(AsyncHandle, Ref, Data, Sent + size(Data))
  after 100 ->
      ct:log("send_until_blocked: stopped after ~B bytes", [Sent]),
      Sent
  end.
