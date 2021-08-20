-module(streaming_upload).

-mode(compile).
-define(TIME, timer:seconds(30)).
-define(CHUNK_SIZE, 8 * 1024 * 1024).

main([Host]) ->
  ok = application:start(erqwest),
  C = erqwest:make_client(),
  {ok, File} = file:open("/dev/zero", [read, raw, binary]),
  {handle, Handle} = erqwest:post(C, list_to_binary(Host), #{body => stream}),
  erlang:send_after(?TIME, self(), stop),
  Start = os:timestamp(),
  Data = loop(File, Handle, 0),
  DiffMs = timer:now_diff(os:timestamp(), Start) div 1000,
  DataMb = Data / 1024.0 / 1024.0,
  io:format("~f MB uploaded in ~B ms, ~f MB/s~n",
            [DataMb, DiffMs, DataMb / (DiffMs / 1000.0)]).

loop(File, Handle, Acc) ->
  receive
    stop -> Acc
  after 0 ->
      {ok, Data} = file:read(File, ?CHUNK_SIZE),
      ok = erqwest:send(Handle, Data),
      loop(File, Handle, size(Data) + Acc)
  end.
