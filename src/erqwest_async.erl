-module(erqwest_async).

-export([ req/4
        , send/2
        , finish_send/1
        , read/2
        , cancel/1
        ]).

-export_type([handle/0]).

-opaque handle() :: erlang:nif_resource().

%% @doc Make an asynchronous request.
%%
%% Response(s) will be sent to `Pid' in the following order:
%%
%% * If `body' is `stream', and the request was successfully initated,
%% `{erqwest_response, Ref, next}'. See {@link send/2} and {@link finish_send/2}
%% for how to respond. It is also possible to receive an `error' response as
%% described below.
%%
%% * `{erqwest_response, Ref, reply, erqwest:resp()}' or
%% `{erqwest_response, Ref, error, erqwest:err()}'
%%
%% * If `response_body' is `stream', see {@link read/2}
%%
%% An `error' response is _always_ the final response. If streaming is not used,
%% a single reply is guaranteed.
%%
%% Fails with reason badarg if any argument is invalid or if the client has
%% already been closed.
-spec req(erqwest:client() | atom(), pid(), any(), erqwest:req_opts()) -> handle().
req(Client, Pid, Ref, Req) ->
  erqwest_nif:req(erqwest:get_client(Client), Pid, Ref, Req).

%% @doc Asynchronously stream a chunk of the request body. Replies with
%% `{erqwest_response, Ref, next}' when the connection is ready to receive more
%% data. Replies with `{erqwest_response, Ref, error, erqwest:err()}' if
%% something goes wrong, or `{erqwest_response, Ref, reply, erqwest:resp()}' if
%% the server has already decided to reply. Call {@link finish_send} when the
%% request body is complete.
-spec send(handle(), iodata()) -> ok.
send(Handle, Data) ->
  erqwest_nif:send(Handle, Data).

%% @doc Complete sending the request body. The message flow continues as
%% described for {@link req/4}, ie. the next message will be `reply' or `error'.
-spec finish_send(handle()) -> ok.
finish_send(Handle) ->
  erqwest_nif:finish_send(Handle).

%% @doc Read a chunk of the response body, waiting for at most `period' ms or
%% until at least `length' bytes have been read. Note that more than `length'
%% bytes can be returned. Replies with `{erqwest_response, Ref, chunk, Data}',
%% `{erqwest_response, Ref, fin, Data}' or `{erqwest_response, Ref, error,
%% erqwest:err()}`. A `fin' or `error' response will be the final message.
-spec read(handle(), erqwest:read_opts()) -> ok.
read(Handle, Opts) ->
  erqwest_nif:read(Handle, Opts).

%% @doc Cancel an asynchronous request at any stage. A reply will always still
%% be sent, either `{error, #{code := cancelled}}', another `error' or a `reply'
%% depending on the state of the connection. Has no effect if the request has
%% already completed or was already cancelled.
-spec cancel(handle()) -> ok.
cancel(Handle) ->
  erqwest_nif:cancel(Handle).
