-module(erlCluster).

-include("erlCluster.hrl").

-export([start/0, stop/0]).


%% API
start() ->
    application:ensure_all_started(erlCluster, permanent).

stop() ->
    ok.
