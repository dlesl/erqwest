-module(erqwest).

-export([ make_client/0
        , make_client/1
        , req_async/4
        , req/2
        , get/2
        , get/3
        , post/3
        ]).

-on_load(init/0).

-opaque client() :: reference().
-type pkcs12_der() :: binary().
-type password() :: binary().
-type client_opts() :: #{ identity => {pkcs12_der(), password()}
                        , follow_redirects => boolean() | non_neg_integer() %% default false
                        }.
-type method() :: options | get | post | put | delete | head | trace | connect | patch.
-type header() :: {binary(), binary()}.
-type url() :: binary().
-type req() :: #{ url := url()
                , method := method()
                , headers => [header()]
                , body => binary()
                , timeout => non_neg_integer() %% milliseconds
                }.
-type req_opts() :: #{ headers => [header()]
                     , body => binary()
                     , timeout => non_neg_integer() %% milliseconds
                     }.
-type resp() :: #{ status := 100..599
                 , body := binary()
                 , headers := [header()]
                 }.
-type err() :: #{ code := atom()
                , reason := binary()
                }.

-export_type([ client/0
             , method/0
             , req/0
             , resp/0
             , err/0
             ]).

-spec make_client() -> client().
make_client() ->
  make_client(#{}).

-spec make_client(client_opts()) -> client().
make_client(_Opts) ->
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

-spec get(client(), url()) -> {ok, resp()} | {error, err()}.
get(Client, Url) ->
  get(Client, Url, #{}).

-spec get(client(), url(), req_opts()) -> {ok, resp()} | {error, err()}.
get(Client, Url, Opts) ->
  req(Client, Opts#{url => Url, method => get}).

-spec post(client(), url(), req_opts()) -> {ok, resp()} | {error, err()}.
post(Client, Url, Opts) ->
  req(Client, Opts#{url => Url, method => post}).

%% internal

init() ->
  Nif = filename:join([code:priv_dir(erqwest), "liberqwest"]),
  ok = erlang:load_nif(Nif, 0).
