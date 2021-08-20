-module(streaming_download).

-mode(compile).
-define(TIME, timer:seconds(30)).

main([Host]) ->
  ok = application:start(erqwest),
  C = erqwest:make_client(),
  {ok, #{body := Handle}} = erqwest:get(C, list_to_binary(Host), #{response_body => stream}),
  erlang:send_after(?TIME, self(), stop),
  Start = os:timestamp(),
  Data = loop(Handle, 0),
  DiffMs = timer:now_diff(os:timestamp(), Start) div 1000,
  DataMb = Data / 1024.0 / 1024.0,
  io:format("~f MB downloaded in ~B ms, ~f MB/s~n",
            [DataMb, DiffMs, DataMb / (DiffMs / 1000.0)]).

loop(Handle, Acc) ->
  receive
    stop -> Acc
  after 0 ->
      {more, Data} = erqwest:read(Handle),
      loop(Handle, size(Data) + Acc)
  end.
