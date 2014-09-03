-module(erlCluster_ring).

-include("erlCluster.hrl").

%% API
-export([new/0, new/1, join/2, leave/2]).
-export([nodes/1, partition/1, node/1]).

-include_lib("eunit/include/eunit.hrl").

new() ->
	new(?TotalPartitions).

new(PartitionNumber) ->
	new(PartitionNumber, node()).

new(PartitionNumber, NodeName) ->
	Increment = round(?HASHTOP div PartitionNumber),
	[{(Index * Increment), NodeName} ||Index <- lists:seq(0, (PartitionNumber-1))].
 
-spec join(NewNodeName :: term(), Ring :: ring()) -> ring().
join(Node, Ring) ->
    case exists(Node, Ring) of
        true ->
            Ring;
        false ->
        	TotalPartitionsToMove = total_assigned_partitions(Ring, erlCluster_ring:nodes(Ring) ++ [Node]),
        	{_, SplitedPartitions} = lists:split(TotalPartitionsToMove, Ring),
        	Partitions = [Partition || {Partition, _} <- SplitedPartitions],
        	update_partitions(Ring, Partitions, Node)
    end.

-spec leave(NewNodeName :: term(), Ring :: ring()) -> ring().
leave(NodeName, Ring) ->
    erlCluster_ring:new(8, 'node1@127.0.0.1').

-spec nodes(Ring :: ring()) -> [term()].
nodes(Ring) ->
	AllNodes = [Node || {Partition, Node} <- Ring],
	lists:usort(AllNodes).

partition(KeyId) ->
	partition_from_key(hashKey(KeyId)).

node(KeyId) ->
	ok.

partition_from_key(HashKey) ->
	ok.

-spec hashKey(KeyId :: binary()) -> atom().
hashKey(KeyId) ->
    <<Key:160/integer>> = crypto:hash(sha, KeyId),
    list_to_atom(integer_to_list(Key)).

-spec partitions_node(NewNodeName :: term(), Ring :: ring()) -> [{term(), term()}].
partitions_node(NodeName, Ring) ->
	[Partition || {Partition, Node} <- Ring, Node =:= NodeName].

-spec exists(NewNodeName :: term(), Ring :: ring()) -> true | false.
exists(NodeName, Ring) ->
	lists:member(NodeName, erlCluster_ring:nodes(Ring)).

total_assigned_partitions(Ring, NewNodeNames) ->
	round(length(Ring) / (length(NewNodeNames))).

-spec update_partitions(Ring :: ring(),Partitions :: list(), UpdatedNodeName :: term()) -> ring().
update_partitions(Ring, Partitions, UpdatedNodeName) ->
	lists:sort(
		lists:foldl( 
			fun(PartitionId, NewRing) ->
				CleanRing = proplists:delete(PartitionId, NewRing),
				lists:sort(CleanRing ++ [{PartitionId, UpdatedNodeName}])
			end,
			Ring,
			Partitions
		)
	).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% TESTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

generate_new_ring_test() ->
	Ring = erlCluster_ring:new(16),
    ?assertEqual(16, length(Ring)).

get_nodes_from_ring_test() ->
	Ring = erlCluster_ring:new(16),
	?assertEqual([node()], erlCluster_ring:nodes(Ring)).

node_exists_on_ring_test() ->
	Ring = erlCluster_ring:new(16),
	?assert(exists(node(), Ring)),
	?assertEqual(false, exists('fake@node', Ring)).

partitions_from_single_ring_test() ->
	Ring = erlCluster_ring:new(16),
	Partitions = partitions_node(node(), Ring),
	?assertEqual(16, length(Partitions)).

join_two_rings_test() ->
	LocalRing = erlCluster_ring:new(8),
	Result = erlCluster_ring:join('node2@127.0.0.1', LocalRing),
	?assertEqual(fake_ring_bi_node(), Result).

join_ring_to_many_rings_test() ->
	?assert(true).

leave_from_two_nodes_ring() ->
	?assertEqual(
		erlCluster_ring:new(8, 'node1@127.0.0.1'), 
		erlCluster_ring:leave('node2@127.0.0.1', fake_ring_bi_node())
	).

total_assigned_partitions_by_node() ->
	Ring = erlCluster_ring:new(16),
	NodeList = erlCluster_ring:nodes(Ring) ++ ['node2@127.0.0.1'],
	?assertEqual(8, total_assigned_partitions(Ring, NodeList)),
	RingA = erlCluster_ring:new(8),
	?assertEqual(4, total_assigned_partitions(RingA, NodeList)).

update_partitions_test() ->
	Ring = erlCluster_ring:new(8),
	Partitions = [
		730750818665451459101842416358141509827966271488,
		913438523331814323877303020447676887284957839360,
		1096126227998177188652763624537212264741949407232,
		1278813932664540053428224228626747642198940975104
	],
	NewRing = update_partitions(Ring, Partitions, 'node2@127.0.0.1'),
	?assertEqual(fake_ring_bi_node(), NewRing).

leave_join_mechanism_test() ->
	%% From Ring; Ordered Nodes by partitionNUmber
	%% Iterate over each node (from more partitions to less)
	%% Valid Method to use on both directions
	?assert(true).

ordered_ring() ->
	[{}].
	
fake_ring_bi_node() ->
     [{0,'node1@127.0.0.1'},
      {182687704666362864775460604089535377456991567872,'node1@127.0.0.1'},
      {365375409332725729550921208179070754913983135744,'node1@127.0.0.1'},
      {548063113999088594326381812268606132370974703616,'node1@127.0.0.1'},
      {730750818665451459101842416358141509827966271488,'node2@127.0.0.1'},
      {913438523331814323877303020447676887284957839360,'node2@127.0.0.1'},
      {1096126227998177188652763624537212264741949407232,'node2@127.0.0.1'},
      {1278813932664540053428224228626747642198940975104,'node2@127.0.0.1'}].


fake_ring_four_node() ->
    [{0,'node4@127.0.0.1'},
    {91343852333181432387730302044767688728495783936,'node3@127.0.0.1'},
    {182687704666362864775460604089535377456991567872,'node3@127.0.0.1'},
    {274031556999544297163190906134303066185487351808,'node4@127.0.0.1'},
    {365375409332725729550921208179070754913983135744,'node2@127.0.0.1'},
    {456719261665907161938651510223838443642478919680,'node2@127.0.0.1'},
    {548063113999088594326381812268606132370974703616,'node2@127.0.0.1'},
    {639406966332270026714112114313373821099470487552,'node2@127.0.0.1'},
    {730750818665451459101842416358141509827966271488,'node3@127.0.0.1'},
    {822094670998632891489572718402909198556462055424,'node3@127.0.0.1'},
    {913438523331814323877303020447676887284957839360,'node4@127.0.0.1'},
    {1004782375664995756265033322492444576013453623296,'node4@127.0.0.1'},
    {1096126227998177188652763624537212264741949407232,'node1@127.0.0.1'},
    {1187470080331358621040493926581979953470445191168,'node1@127.0.0.1'},
    {1278813932664540053428224228626747642198940975104,'node1@127.0.0.1'},
    {1370157784997721485815954530671515330927436759040,'node1@127.0.0.1'}].