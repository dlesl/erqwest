%% @private
-module(erqwest_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_all},
    ChildSpecs = [#{ id => erqwest_runtime
                   , start => {erqwest_runtime, start_link, []}
                   }],
    {ok, {SupFlags, ChildSpecs}}.
