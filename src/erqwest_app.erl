%% @private
-module(erqwest_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    erqwest_sup:start_link().

stop(_State) ->
    ok.
