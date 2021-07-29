-module(bench).


-mode(compile).
-define(HOST, <<"http://localhost:8181">>).
-define(HOST_TLS, <<"https://localhost:8443">>).
-define(ECHO, <<"/echo">>).
-define(WORKERS, 50).
-define(TIME, timer:seconds(30)).
-define(KATIPO_POOL, pool).
-define(KATIPO_POOL_SIZE, 8).

main([Client0]) ->
  Client = list_to_atom(Client0),
  Fun = req_fun(Client),
  run(Client, http, Fun),
  run(Client, https, Fun).

run(Name, http, Fun) ->
  io:format("=== Benchmarking ~p, no TLS, ~B workers ===~n", [Name, ?WORKERS]),
  bench(fun() -> Fun(<<?HOST/binary, ?ECHO/binary>>) end);
run(Name, https, Fun) ->
  io:format("=== Benchmarking ~p, TLS, ~B workers ===~n", [Name, ?WORKERS]),
  bench(fun() -> Fun(<<?HOST_TLS/binary, ?ECHO/binary>>) end).

bench(Fun) ->
  Self = self(),
  Start = os:timestamp(),
  Workers = [spawn(fun() -> worker(Self, Fun, 0) end) || _ <- lists:seq(1, ?WORKERS)],
  timer:sleep(?TIME),
  [W ! stop || W <- Workers],
  Results = [receive Res -> Res end || _ <- lists:seq(1, ?WORKERS)],
  DiffMs = timer:now_diff(os:timestamp(), Start) div 1000,
  Success = lists:sum([N || {ok, N} <- Results]) + lists:sum([N || {error, N} <- Results]),
  io:format("~B requests succeeded in ~B ms, ~f r/s~n", [Success, DiffMs, Success / (DiffMs / 1000.0)]),
  ok.

worker(Pid, Fun, Count) ->
  receive
    stop -> Pid ! {ok, Count}
  after 0 ->
      try Fun() of
        _ -> worker(Pid, Fun, Count + 1)
      catch T:R:S ->
          io:format("worker failed after ~B with ~p:~p:~p~n", [Count, T, R, S]),
          Pid ! {error, Count}
      end
  end.

req_fun(erqwest) ->
  {ok, _} = application:ensure_all_started(erqwest),
  {ok, PemBin} = file:read_file("cert.crt"),
  [{'Certificate', Cert, _}] = public_key:pem_decode(PemBin),
  C = erqwest:make_client(#{additional_root_certs => [Cert]}),
  fun(Url) ->
      {ok, #{status := 200, body := <<"hey">>}} =
        erqwest:post(C, Url, #{body => <<"hey">>})
  end;
req_fun(katipo) ->
  {ok, _} = application:ensure_all_started(katipo),
  {ok, _} = katipo_pool:start(?KATIPO_POOL, ?KATIPO_POOL_SIZE, [{pipelining, multiplex}]),
  fun(Url) ->
      {ok, #{status := 200, body := <<"hey">>}} =
        katipo:post(?KATIPO_POOL, Url, #{ body => <<"hey">>
                                        , ssl_verifypeer => false
                                        , ssl_verifyhost => false
                                        })
  end;
req_fun(hackney) ->
  {ok, _} = application:ensure_all_started(hackney),
  fun(Url) ->
      {ok, 200, _, <<"hey">>} =
        hackney:post(Url, [], <<"hey">>, [with_body, {ssl_options, [{verify, verify_none}]}])
  end.
