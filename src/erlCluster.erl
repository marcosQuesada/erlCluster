-module(erlCluster).

-include("erlCluster.hrl").

-export([start/0, stop/0, set/2, get/1, command/2]).


%% API
start() ->
    application:ensure_all_started(erlCluster, permanent).

stop() ->
    ok.

%%%% Command implementations
get(Key) ->
	command(Key, [get, Key]).

set(Key, Value) ->
	command(Key, [get, Key, Value]).

command(Key, Args) ->
	Ring = erlCluster_node:map_ring(),
	{PartitionId, Node} = erlCluster_ring:partition(Key, Ring),
	erlCluster_node:command(PartitionId, Node, Args).