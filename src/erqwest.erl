-module(erqwest).

-export([ feature/1
        , make_client/0
        , make_client/1
        , close_client/1
        , start_client/1
        , start_client/2
        , stop_client/1
        , get_client/1
        , req/2
        , send/2
        , finish_send/1
        , read/1
        , read/2
        , cancel/1
        , get/2
        , get/3
        , post/3
        , put/3
        , delete/3
        , patch/3
        ]).

-export_type([ client/0
             , method/0
             , req_opts/0
             , read_opts/0
             , resp/0
             , err/0
             , handle/0
             ]).

-opaque client() :: erlang:nif_resource().

-record(handle, { inner :: erlang:nif_resource()
                , ref :: reference()
                , owner :: pid()
                }).
-opaque handle() :: #handle{}.

%% rules are applied in order, see https://docs.rs/reqwest/0.11.4/reqwest/struct.Proxy.html
-type proxy_config() :: [{http | https | all, proxy_spec()}].
-type proxy_spec() :: #{ url := binary()
                       , basic_auth => {Username::binary(), Password::binary()}
                       }.
-type timeout_ms() :: non_neg_integer() | infinity.
-type client_opts() :: #{ identity => {Pkcs12Der::binary(), Password::binary()}
                        , follow_redirects => boolean() | non_neg_integer() %% default true
                        , additional_root_certs => [CertDer::binary()]
                        , use_built_in_root_certs => boolean() %% default true
                        , danger_accept_invalid_hostnames => boolean() %% default false
                        , danger_accept_invalid_certs => boolean() %% default false
                        , proxy => system | no_proxy | proxy_config() %% default system
                        , connect_timeout => timeout_ms()
                        , timeout => timeout_ms()
                        , pool_idle_timeout => timeout_ms()
                        , pool_max_idle_per_host => non_neg_integer()
                        , https_only => boolean() %% default false
                        , cookie_store => boolean() %% default false
                        , gzip => boolean() %% default false
                        }.
-type method() :: options | get | post | put | delete | head | trace | connect | patch.
-type header() :: {binary(), binary()}.
-type req_opts() :: #{ url := binary()
                     , method := method()
                     , headers => [header()]
                     , body => iodata() | stream %% default empty
                     , response_body => complete | stream %% default complete
                     , timeout => timeout_ms()
                     }.
-type req_opts_optional() :: #{ headers => [header()]
                              , body => iodata() | stream %% default empty
                              , timeout => timeout_ms()
                              , body => iodata() | stream %% default empty
                              , response_body => complete | stream %% default complete
                              }.
-type read_opts() :: #{ period => timeout_ms()
                      , length => pos_integer()
                      }.
-type resp() :: #{ status := 100..599
                 , body := binary() | handle()
                 , headers := [header()]
                 }.
-type err() :: #{ code := timeout | redirect | url | connect | request | body | cancelled | unknown
                , reason := binary()
                }.
-type feature() :: cookies | gzip.

-include_lib("stdlib/include/assert.hrl").

%% Because the pid that messages are sent to is fixed, handle() can't be passed
%% between processes.
-define(assertOwner(Handle),
        ?assertEqual(self(), Handle#handle.owner,
                     "handle() may only be used by one process")).

%% @doc Determines whether a compile-time feature is available. Enable features
%% by adding them to the environment variable `ERQWEST_FEATURES' (comma
%% separated list) at build time.
-spec feature(feature()) -> boolean().
feature(Feature) ->
  erqwest_nif:feature(Feature).

%% @equiv make_client(#{})
-spec make_client() -> client().
make_client() ->
  make_client(#{}).

%% @doc Make a new client with its own connection pool. See also {@link start_client/2}.
-spec make_client(client_opts()) -> client().
make_client(Opts) ->
  erqwest_nif:make_client(erqwest_runtime:get(), Opts).

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
close_client(Client) ->
  erqwest_nif:close_client(Client).

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

%% @private
get_client(Client) when is_atom(Client) ->
  persistent_term:get({?MODULE, Client});
get_client(Client) ->
  Client.

%% @doc Make a synchronous request.
%%
%% Fails with reason badarg if any argument is invalid or if the client has
%% already been closed. If you set `body' to `stream', you will get back
%% `{handle, handle()}', which you need to pass to {@link send/2} and {@link
%% finish_send/1} to stream the request body. If you set `response_body' to
%% `stream', the `body' key in `resp()' be a `handle()' that you need to pass to
%% `read' to consume the response body. If you decide not to consume the
%% response body, call {@link cancel/1}.
-spec req(client() | atom(), req_opts()) ->
        {ok, resp()} | {handle, handle()} | {error, err()}.
req(Client, #{body := stream}=Req) ->
  Inner = erqwest_nif:req(get_client(Client), self(), Ref=make_ref(), Req),
  receive
    {erqwest_response, Ref, next} ->
      {handle, #handle{inner=Inner, ref=Ref, owner=self()}};
    {erqwest_response, Ref, error, Resp} ->
      {error, Resp}
  end;
req(Client, Req) ->
  Inner = erqwest_nif:req(get_client(Client), self(), Ref=make_ref(), Req),
  receive
    {erqwest_response, Ref, reply, Resp} ->
      case Req of
        #{response_body := stream} ->
          {ok, Resp#{body => #handle{inner=Inner, ref=Ref, owner=self()}}};
        #{} ->
          {ok, Resp}
      end;
    {erqwest_response, Ref, error, Resp} ->
      {error, Resp}
  end.

%% @doc Stream a chunk of the request body. Returns `ok' once the chunk has
%% successfully been queued for transmission. Note that due to buffering this
%% does not mean that the chunk has actually been sent. Blocks once the internal
%% buffer is full. Call {@link finish_send/1} once the body is complete.
%% `{reply, resp()}' is returned if the server chooses to reply before the
%% request body is complete.
-spec send(handle(), iodata()) ->
        ok | {reply, resp()} | {error, err()}.
send(#handle{inner=Inner, ref=Ref}=Handle, Data) ->
  ?assertOwner(Handle),
  ok = erqwest_nif:send(Inner, Data),
  receive
    {erqwest_response, Ref, next} -> ok;
    {erqwest_response, Ref, reply, Resp} -> {reply, maybe_stream(Handle, Resp)};
    {erqwest_response, Ref, error, Err} -> {error, Err}
  end.

%% @doc Complete sending the request body. Awaits the server's reply. Return
%% values are as described for {@link req/2}.
-spec finish_send(handle()) -> {ok, resp()} | {error, err()}.
finish_send(#handle{inner=Inner, ref=Ref}=Handle) ->
  ?assertOwner(Handle),
  erqwest_nif:finish_send(Inner),
  receive
    {erqwest_response, Ref, reply, Resp} -> {ok, maybe_stream(Handle, Resp)};
    {erqwest_response, Ref, error, Err} -> {error, Err}
  end.

%% @equiv read(Handle, #{})
-spec read(handle()) -> {more, binary()} | {ok, binary()} | {error, err()}.
read(Handle) ->
  read(Handle, #{}).

%% @doc Read a chunk of the response body, waiting for at most `period' ms or
%% until at least `length' bytes have been read. `length' defaults to 8 MB if
%% omitted, and `period' to `infinity'. Note that more than `length' bytes can
%% be returned. Returns `{more, binary()}' if there is more data to be read, and
%% `{ok, binary()}' once the body is complete.
-spec read(handle(), map() | cancel) ->
        {more, binary()} | {ok, binary()} | {error, err()}.
read(#handle{inner=Inner, ref=Ref}=Handle, Opts) ->
  ?assertOwner(Handle),
  ok = erqwest_nif:read(Inner, Opts),
  receive
    {erqwest_response, Ref, chunk, Data} -> {more, Data};
    {erqwest_response, Ref, fin, Data} -> {ok, Data};
    {erqwest_response, Ref, error, Err} -> {error, Err}
  end.

%% @doc Used to cancel streaming of a request or response body.
-spec cancel(handle()) -> ok.
cancel(#handle{inner=Inner}=Handle) ->
  ?assertOwner(Handle),
  erqwest_nif:cancel_stream(Inner).


%% @doc Convenience wrapper for {@link req/2}.
-spec get(client() | atom(), binary()) ->
        {ok, resp()} | {handle, handle()} | {error, err()}.
get(Client, Url) ->
  get(Client, Url, #{}).

%% @doc Convenience wrapper for {@link req/2}.
-spec get(client() | atom(), binary(), req_opts_optional()) ->
        {ok, resp()} | {handle, handle()} | {error, err()}.
get(Client, Url, Opts) ->
  req(Client, Opts#{url => Url, method => get}).

%% @doc Convenience wrapper for {@link req/2}.
-spec post(client() | atom(), binary(), req_opts_optional()) ->
        {ok, resp()} | {handle, handle()} | {error, err()}.
post(Client, Url, Opts) ->
  req(Client, Opts#{url => Url, method => post}).

%% @doc Convenience wrapper for {@link req/2}.
-spec put(client() | atom(), binary(), req_opts_optional()) ->
        {ok, resp()} | {handle, handle()} | {error, err()}.
put(Client, Url, Opts) ->
  req(Client, Opts#{url => Url, method => put}).

%% @doc Convenience wrapper for {@link req/2}.
-spec delete(client() | atom(), binary(), req_opts_optional()) ->
        {ok, resp()} | {handle, handle()} | {error, err()}.
delete(Client, Url, Opts) ->
  req(Client, Opts#{url => Url, method => delete}).

%% @doc Convenience wrapper for {@link req/2}.
-spec patch(client() | atom(), binary(), req_opts_optional()) ->
        {ok, resp()} | {handle, handle()} | {error, err()}.
patch(Client, Url, Opts) ->
  req(Client, Opts#{url => Url, method => patch}).

%% internal functions

maybe_stream(_Handle, Resp) when is_map_key(body, Resp) ->
  Resp;
maybe_stream(Handle, Resp) ->
  Resp#{body => Handle}.
