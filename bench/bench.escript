-module(bench).


-mode(compile).
-define(HOST, <<"https://localhost:8443">>).
-define(ECHO, <<?HOST/binary, "/echo">>).
-define(WORKERS, 50).
-define(TIME, timer:seconds(30)).
-define(KATIPO_POOL, pool).
-define(KATIPO_POOL_SIZE, 8).

main(["erqwest"]) ->
  {ok, _} = application:ensure_all_started(erqwest),
  {ok, PemBin} = file:read_file("cert.crt"),
  [{'Certificate', Cert, _}] = public_key:pem_decode(PemBin),
  C = erqwest:make_client(#{additional_root_certs => [Cert]}),
  Fun = fun() ->
            {ok, #{status := 200, body := <<"hey">>}} =
              erqwest:post(C, ?ECHO, #{body => <<"hey">>})
        end,
  bench(Fun);
main(["katipo"]) ->
  {ok, _} = application:ensure_all_started(katipo),
  {ok, _} = katipo_pool:start(?KATIPO_POOL, ?KATIPO_POOL_SIZE, [{pipelining, multiplex}]),
  Fun = fun() ->
            {ok, #{status := 200, body := <<"hey">>}} =
              katipo:post(?KATIPO_POOL, ?ECHO, #{ body => <<"hey">>
                                                , ssl_verifypeer => false
                                                , ssl_verifyhost => false
                                                })
        end,
  bench(Fun);
main(["hackney"]) ->
  {ok, _} = application:ensure_all_started(hackney),
  Fun = fun() ->
            {ok, 200, _, <<"hey">>} =
              hackney:post(?ECHO, [], <<"hey">>, [with_body, {ssl_options, [{verify, verify_none}]}])
        end,
  bench(Fun).

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
