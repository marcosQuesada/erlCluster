-module(erlCluster).

-include("erlCluster.hrl").

-export([start/0, stop/0, join/1, leave/0, handle_command/2]).

-export([set/2, get/1, size/0]).

%% API
start() ->
    application:ensure_all_started(erlCluster, permanent).

stop() ->
    ok.

-spec join(NodeName::atom()) -> term().
join(NodeName) ->
	case net_adm:ping(NodeName) of
		pong ->
            timer:sleep(1000),
			erlCluster_node:join(NodeName);
		Other ->
			io:format("Join failed: ~p ~n", [Other])
	end.

-spec leave() -> term().
leave() ->
	erlCluster_node:leave().

%%%% handle_Command implementations
-spec get(Key::term()) -> term().
get(Key) ->
	handle_command(Key, {get, Key}).

-spec set(Key::term(), Value::term()) -> ok | {error, term()}.
set(Key, Value) ->
	handle_command(Key, {set, Key, Value}).

-spec size()-> integer().
size() ->
	lists:foldl(
		fun({PartitionId, _}, Acc) ->
			Size = handle_command(PartitionId, size),
			io:format("Partition ~p size ~p ~n", [PartitionId, Size]),
			Acc + Size
		end,
		0,
		erlCluster_node:map_ring()
	).

-spec handle_command(Key::term(), Args::term()) -> term().
handle_command(Key, Args) ->
	erlCluster_node:handle_command(Key, Args).