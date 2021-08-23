-module(server).

-export([ listen/0
        , accept/1
        , read/1
        , read/2
        , read_silent/2
        , reply/2
        , send/2
        , close/1
        , wait_for_close/1
        ]).

listen() ->
  {ok, LSock} = gen_tcp:listen(0, [binary, {packet, raw}, {active, false}]),
  {ok, Port} = inet:port(LSock),
  Url = <<"http://localhost:", (integer_to_binary(Port))/binary>>,
  {LSock, Url}.

accept(LSock) ->
  {ok, Sock} = gen_tcp:accept(LSock),
  ok = gen_tcp:close(LSock),
  Sock.

read(Sock) ->
  read(Sock, 0).

read(Sock, N) ->
  {ok, Read} = gen_tcp:recv(Sock, N),
  ct:log("read ~s", [Read]).

read_silent(Sock, N) ->
  {ok, Read} = gen_tcp:recv(Sock, N),
  ct:log("read ~B bytes", [size(Read)]).

reply(Sock, Headers0) ->
  Headers = ["Connection: close"|Headers0],
  Data = ["HTTP/1.1 200 OK\r\n", lists:join("\r\n", Headers), "\r\n\r\n"],
  ct:log("reply ~s", [Data]),
  ok = gen_tcp:send(Sock, Data).

send(Sock, Data) ->
  ct:log("send ~s", [Data]),
  ok = gen_tcp:send(Sock, Data).

close(Sock) ->
  ct:log("close socket"),
  ok = gen_tcp:shutdown(Sock, read_write).

wait_for_close(Sock) ->
  Data = drain(Sock, []),
  ct:log("closed after ~B bytes", [iolist_size(Data)]),
  Data.

drain(Sock, Acc) ->
  case gen_tcp:recv(Sock, 0) of
    {ok, Data} ->
      ct:log("draining ~s", [Data]),
      drain(Sock, [Data|Acc]);
    {error, closed} ->
      lists:reverse(Acc)
  end.
