-module(erlCloud_ring).

-include("erlCloud.hrl").

%% API
-export([new/0, new/1, join/2, leave/2]).
-export([nodes/1, partition/1, node/1]).


new() ->
	new(?TotalPartitions).

new(PartitionNumber) ->
	Increment = round(?HASHTOP div PartitionNumber),
	[{(Index * Increment), node()} ||Index <- lists:seq(0, (PartitionNumber-1))].
 
join(Ring1, Ring2) ->
	ok.

leave(Ring1, Ring2) ->
	ok.

nodes(Ring) ->
	[].

partition(KeyId) ->
	ok.

node(KeyId) ->
	ok.

-spec hashKey(KeyId :: binary()) -> atom().
hashKey(KeyId) ->
    <<Key:160/integer>> = crypto:hash(sha, KeyId),
    list_to_atom(integer_to_list(Key)).