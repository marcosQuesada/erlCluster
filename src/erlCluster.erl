-module(erlCluster).

-include("erlCluster.hrl").

-export([start/0, stop/0, join/1, leave/0, command/2]).

-export([set/2, get/1]).


%% API
start() ->
    application:ensure_all_started(erlCluster, permanent).

stop() ->
    ok.

join(NodeName) ->
	erlCluster_node:join(NodeName).

leave() ->
	erlCluster_node:leave().

%%%% Command implementations
get(Key) ->
	command(Key, [get, Key]).

set(Key, Value) ->
	command(Key, [get, Key, Value]).

command(Key, Args) ->
	Ring = erlCluster_node:map_ring(),
	{PartitionId, Node} = erlCluster_ring:partition(Key, Ring),
	erlCluster_node:command(PartitionId, Node, Args).