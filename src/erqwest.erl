-module(erqwest).

-export([ make_client/0
        , make_client/1
        , close_client/1
        , start_client/1
        , start_client/2
        , stop_client/1
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
-type cert_der() :: binary().
-type client_opts() :: #{ identity => {pkcs12_der(), password()}
                        , follow_redirects => boolean() | non_neg_integer() %% default false
                        , additional_root_certs => [cert_der()]
                        , use_built_in_root_certs => boolean() %% default true
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
-type err_code() :: timeout | redirect | connect | request | body | unknown.
-type err() :: #{ code := err_code()
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
  erlang:nif_error(nif_not_loaded).

%% @doc Close a client and idle connections in its pool. Returns immediately,
%% but the connection pool will not be cleaned up until all in-flight requests
%% for this client have returned.
%%
%% You do not have to call this function, since
%% the client will automatically be cleaned up when it is garbage collected by
%% the VM.
%%
%% Fails with reason badarg if the client has already been closed.
-spec close_client(client()) -> ok.
close_client(_Client) ->
  erlang:nif_error(nif_not_loaded).

%% @equiv start_client(Name, #{})
-spec start_client(atom()) -> ok.
start_client(Name) ->
  start_client(Name, #{}).

%% @doc Start a client registered under `Name'. The implementation uses
%% `persistent_term' and is not intended for clients that will be frequently
%% started and stopped. For such uses see {@link make_client/1}.
-spec start_client(atom(), client_opts()) -> ok.
start_client(Name, Opts) ->
  Client = make_client(Opts),
  persistent_term:put({?MODULE, Name}, Client).

%% @doc Unregisters and calls {@link close_client/1} on a named client. This is
%% potentially expensive and should not be called frequently, see {@link
%% start_client/2} for more details.
-spec stop_client(atom()) -> ok.
stop_client(Name) ->
  Client = persistent_term:get({?MODULE, Name}),
  persistent_term:erase({?MODULE, Name}),
  close_client(Client).

%% @doc Make an asynchronous request.
%%
%% Sends `{erqwest_response, Ref, {ok, resp()} | {error, err()}}' to `Pid'.
%%
%% Fails with reason badarg if any argument is invalid or if the client has
%% already been closed.
-spec req_async(client() | atom(), pid(), any(), req()) -> ok.
req_async(NamedClient, Pid, Ref, Req) when is_atom(NamedClient) ->
  Client = persistent_term:get({?MODULE, NamedClient}),
  req_async_internal(Client, Pid, Ref, Req);
req_async(Client, Pid, Ref, Req) ->
  req_async_internal(Client, Pid, Ref, Req).

%% @doc Make a synchronous request.
%%
%% Fails with reason badarg if any argument is invalid or if the client has
%% already been closed.
-spec req(client() | atom(), req()) -> {ok, resp()} | {error, err()}.
req(Client, Req) ->
  ok = req_async(Client, self(), Ref=make_ref(), Req),
  receive
    {erqwest_response, Ref, Resp} -> Resp
  end.

%% @doc Convenience wrapper for {@link req/2}.
-spec get(client() | atom(), url()) -> {ok, resp()} | {error, err()}.
get(Client, Url) ->
  get(Client, Url, #{}).

%% @doc Convenience wrapper for {@link req/2}.
-spec get(client() | atom(), url(), req_opts()) -> {ok, resp()} | {error, err()}.
get(Client, Url, Opts) ->
  req(Client, Opts#{url => Url, method => get}).

%% @doc Convenience wrapper for {@link req/2}.
-spec post(client() | atom(), url(), req_opts()) -> {ok, resp()} | {error, err()}.
post(Client, Url, Opts) ->
  req(Client, Opts#{url => Url, method => post}).

%% internal

init() ->
  Nif = filename:join([code:priv_dir(erqwest), "liberqwest"]),
  ok = erlang:load_nif(Nif, 0).

req_async_internal(_Client, _Pid, _Ref, _Req) ->
  erlang:nif_error(nif_not_loaded).
