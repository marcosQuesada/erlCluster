-module(erlCluster).

-include("erlCluster.hrl").

-export([start/0, stop/0, join/1, leave/0, command/2]).

-export([set/2, get/1, size/0]).

%% API
start() ->
    application:ensure_all_started(erlCluster, permanent).

stop() ->
    ok.

-spec join(NodeName::atom()) -> term().
join(NodeName) ->
	erlCluster_node:join(NodeName).

-spec leave() -> term().
leave() ->
	erlCluster_node:leave().

%%%% Command implementations
-spec get(Key::integer()) -> term().
get(Key) ->
	command(Key, {get, Key}).

-spec set(Key::integer(), Value::term()) -> term().
set(Key, Value) ->
	command(Key, {set, Key, Value}).

-spec size()-> integer().
size() ->
	lists:foldl( 
		fun({PartitionId, _}, Acc) ->
			Size = command(PartitionId, size),
			io:format("Partition ~p size ~p ~n", [PartitionId, Size]),
			Acc + Size
		end,
		0,
		erlCluster_node:map_ring()
	).

-spec command(Key::integer(), Args::term()) -> term().
command(Key, Args) ->
	Ring = erlCluster_node:map_ring(),
	{PartitionId, Node} = erlCluster_ring:partition(Key, Ring),
	erlCluster_node:command(PartitionId, Node, Args).