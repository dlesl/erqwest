%% @private
%%
%% This gen_server monitors the tokio runtime so that its failure can be handled
%% by the supervision tree (for example in the case of a panic). Since this is
%% not expected to happen, the reference to the runtime is stored in a
%% persistent_term for efficiency.

-module(erqwest_runtime).

-behaviour(gen_server).

-export([start_link/0, get/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2]).

-record(state, {runtime}).

-define(SERVER, ?MODULE).

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

get() ->
  persistent_term:get(?MODULE).

%% gen_server implementation

init([]) ->
  process_flag(trap_exit, true),
  Runtime = erqwest_nif:start_runtime(self()),
  persistent_term:put(?MODULE, Runtime),
  {ok, #state{runtime=Runtime}}.

handle_call(_Request, _From, State) ->
  {reply, ok, State}.

handle_cast(_Request, State) ->
  {noreply, State}.

handle_info(erqwest_runtime_stopped, State) ->
  {stop, erqwest_runtime_failure, State#state{runtime=undefined}};
handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, #state{runtime=undefined}) ->
  ok;
terminate(_Reason, #state{runtime=Runtime}) ->
  erqwest_nif:stop_runtime(Runtime),
  receive
    erqwest_runtime_stopped -> ok
  end.
