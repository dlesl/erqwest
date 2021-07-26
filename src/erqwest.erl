-module(erqwest).

-export([ make_client/0
        , req_async/4
        , req/2
        ]).

-on_load(init/0).

-opaque client() :: reference().
-type method() :: options | get | post | put | delete | head | trace | connect | patch.
-type header() :: {binary(), binary()}.
-type req() :: #{ url := binary()
                , method := method()
                , headers => [header()]
                , body => binary()
                }.
-type resp() :: #{ code := 100..599
                 , body := binary()
                 , headers := [header()]
                 }.
-type err() :: #{ reason := binary() }.

-export_type([ client/0
             , method/0
             , req/0
             , resp/0
             , err/0
             ]).

-spec make_client() -> client().
make_client() ->
  error(nif_not_loaded).

%% @doc Sends {erqwest_response, Ref, {ok, resp()} | {error, err()}} to Pid
-spec req_async(client(), pid(), any(), req()) -> ok.
req_async(_Client, _Pid, _Ref, _Req) ->
  error(nif_not_loaded).

-spec req(client(), req()) -> {ok, resp()} | {error, err()}.
req(Client, Req) ->
  ok = req_async(Client, self(), Ref=make_ref(), Req),
  receive
    {erqwest_response, Ref, Resp} -> Resp
  end.

%% internal

init() ->
  Nif = filename:join([code:priv_dir(erqwest), "liberqwest"]),
  ok = erlang:load_nif(Nif, 0).
