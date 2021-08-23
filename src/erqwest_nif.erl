%% @private

-module(erqwest_nif).

-export([ feature/1
        , start_runtime/1
        , stop_runtime/1
        , make_client/2
        , close_client/1
        , req/4
        , send/2
        , finish_send/1
        , read/2
        , cancel/1
        , cancel_stream/1
        ]).

-on_load(init/0).

-define(APP, erqwest).
-define(NIF, "liberqwest").

-define(nif_stub, erlang:nif_error(nif_not_loaded)).

init() ->
  Nif = filename:join([code:priv_dir(?APP), ?NIF]),
  ok = erlang:load_nif(Nif, 0).

feature(_Feature) -> ?nif_stub.
start_runtime(_Pid) -> ?nif_stub.
stop_runtime(_Runtime) -> ?nif_stub.
make_client(_Runtime, _Opts) -> ?nif_stub.
close_client(_Client) -> ?nif_stub.
req(_Client, _Pid, _Ref, _Opts) -> ?nif_stub.
send(_Handle, _Data) -> ?nif_stub.
finish_send(_Handle) -> ?nif_stub.
read(_Handle, _Opts) -> ?nif_stub.
cancel(_Handle) -> ?nif_stub.
cancel_stream(_Handle) -> ?nif_stub.
