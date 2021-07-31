-module(bench).


-mode(compile).
-define(HOST, <<"http://localhost:8181">>).
-define(HOST_TLS, <<"https://localhost:8443">>).
-define(ECHO, <<"/echo">>).
-define(WORKERS, 50).
-define(TIME, timer:seconds(30)).
-define(KATIPO_POOL, pool).
-define(KATIPO_POOL_SIZE, 8).
-define(PAYLOAD_SIZE, 10 * 1024).
-define(PAYLOAD, << <<0>> || _ <- lists:seq(1, ?PAYLOAD_SIZE) >>).

main([Client0]) ->
  Client = list_to_atom(Client0),
  Fun = req_fun(Client, ?PAYLOAD),
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
  Workers = [spawn(fun() -> worker(Self, Fun, 0, 0) end) || _ <- lists:seq(1, ?WORKERS)],
  timer:sleep(?TIME),
  [W ! stop || W <- Workers],
  Results = [receive Res -> Res end || _ <- lists:seq(1, ?WORKERS)],
  DiffMs = timer:now_diff(os:timestamp(), Start) div 1000,
  {Success0, Error0} = lists:unzip(Results),
  Success = lists:sum(Success0),
  Error = lists:sum(Error0),
  io:format("~B requests succeeded in ~B ms, ~f r/s, ~B errors~n",
            [Success, DiffMs, Success / (DiffMs / 1000.0), Error]).

worker(Pid, Fun, Success, Error) ->
  receive
    stop -> Pid ! {Success, Error}
  after 0 ->
      try Fun() of
        _ -> worker(Pid, Fun, Success + 1, Error)
      catch T:R:S ->
          io:format("worker failed with ~p:~p:~p~n", [T, R, S]),
          worker(Pid, Fun, Success, Error + 1)
      end
  end.

req_fun(erqwest, Payload) ->
  {ok, _} = application:ensure_all_started(erqwest),
  {ok, PemBin} = file:read_file("cert.crt"),
  [{'Certificate', Cert, _}] = public_key:pem_decode(PemBin),
  C = erqwest:make_client(#{ additional_root_certs => [Cert]
                           , danger_accept_invalid_hostnames => true
                           , danger_accept_invalid_certs => true
                           }),
  fun(Url) ->
      {ok, #{status := 200, body := Payload}} =
        erqwest:post(C, Url, #{body => Payload})
  end;
req_fun(katipo, Payload) ->
  {ok, _} = application:ensure_all_started(katipo),
  {ok, _} = katipo_pool:start(?KATIPO_POOL, ?KATIPO_POOL_SIZE, [{pipelining, multiplex}]),
  fun(Url) ->
      {ok, #{status := 200, body := Payload}} =
        katipo:post(?KATIPO_POOL, Url, #{ body => Payload
                                        , ssl_verifypeer => false
                                        , ssl_verifyhost => false
                                        })
  end;
req_fun(hackney, Payload) ->
  {ok, _} = application:ensure_all_started(hackney),
  fun(Url) ->
      {ok, 200, _, Payload} =
        hackney:post(Url, [], Payload, [with_body, {ssl_options, [ {verify, verify_none}
                                                                   %% silence insecure ssl warnings
                                                                 , {log_level, error}
                                                                 ]}])
  end.
