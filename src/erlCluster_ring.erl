-module(erlCluster_ring).

-include("erlCluster.hrl").

%% API
-export([new/0, new/1, join/2, leave/2]).
-export([nodes/1, partition/2, node/1]).

-export([partitions_node/2, process/1, reorder/2, pickPartitions/2]).

-include_lib("eunit/include/eunit.hrl").

new() ->
	new(?TotalPartitions).

new(PartitionNumber) ->
	new(PartitionNumber, node()).

new(PartitionNumber, NodeName) ->
	Increment = round(?HASHTOP div PartitionNumber),
	[{(Index * Increment), NodeName} ||Index <- lists:seq(0, (PartitionNumber-1))].
 
-spec join(Node :: term(), Ring :: ring()) -> ring().
join(Node, Ring) ->
    case exists(Node, Ring) of
        true ->
            Ring;
        false ->
        	TotalPartitionsToMove = total_assigned_partitions(Ring, erlCluster_ring:nodes(Ring) ++ [Node]),
 			Partitions = pickPartitions(Ring,TotalPartitionsToMove),
			update_ring(Ring, Partitions, Node)
    end.

-spec leave(NodeName :: term(), Ring :: ring()) -> ring().
leave(NodeName, Ring) ->

	OrderedRing = reorder(process(Ring),up),
	PartitionsToMove = proplists:get_value(NodeName, OrderedRing),
	CleannedOrderedRing = proplists:delete(NodeName, OrderedRing),

	{ResultRing,_} = lists:foldl( 
		fun(Partition, {NewRing, NodeList}) ->
			case length(NodeList) of
				1 ->
					Tail = [],
					[NextNode] = NodeList;
				_ ->
					[NextNode|Tail] = NodeList
			end,
			UpdatedRing = update_ring(NewRing, [Partition], NextNode),
			{UpdatedRing, Tail ++ [NextNode]}
		end,
		{Ring, proplists:get_keys(CleannedOrderedRing)},
		PartitionsToMove
	),	
	ResultRing.


-spec nodes(Ring :: ring()) -> [term()].
nodes(Ring) ->
	AllNodes = [Node || {Partition, Node} <- Ring],
	lists:usort(AllNodes).

partition(KeyId, Ring) ->
	{0, node()}.
	%partition_from_key(hashKey(KeyId)).

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
	Total = round(length(Ring) / length(NewNodeNames)),
	case (length(Ring) rem length(NewNodeNames)) of
		0 ->
			Total;
		_ ->
			Total + 1
	end.

-spec update_partitions(Ring :: ring(),Partitions :: list(), UpdatedNodeName :: term()) -> ring().
update_partitions(Ring, Partitions, UpdatedNodeName) ->
		lists:foldl( 
			fun(PartitionId, NewRing) ->
				CleanRing = proplists:delete(PartitionId, NewRing),
				CleanRing ++ [{PartitionId, UpdatedNodeName}]
			end,
			Ring,
			Partitions
		).

%% Process Ring to generate a list of nodes an its partitions
-spec process(Ring::ring()) -> [{term(), list()}].
process(Ring) ->
	lists:sort(
		lists:foldl( 
			fun(Node, OrderedRing) ->
				Partitions = erlCluster_ring:partitions_node(Node, Ring),
				OrderedRing ++ [{Node, Partitions}]
			end,
			[],
			erlCluster_ring:nodes(Ring)
		)
	).

%%-spec reorder(OrderedRing::[{term(), list()}, up::term()]) -> [{term(), list()}].
reorder(OrderedRing, down) ->
	[{Node, proplists:get_value(Node, OrderedRing)} ||{_, Node} <- sort_ordered_ring(OrderedRing)];

reorder(OrderedRing, up) ->
	lists:reverse(reorder(OrderedRing, down));

reorder(OrderedRing, _) ->
	{error, not_allowed}.

-spec sort_ordered_ring(OrderedRing::[{term(), list()}]) -> [{integer(), term()}].
sort_ordered_ring(OrderedRing) ->
	lists:sort([{length(Partitions), Node} || {Node, Partitions} <-OrderedRing]).

-spec pickPartitions(Ring::ring(), TotalPartitions::integer()) -> list().
pickPartitions(Ring, TotalPartitions) ->
	OrderedRing = reorder(process(Ring),up),
	Nodes = [Node || {Node, _} <- OrderedRing],
	{_, Partitions} = lists:foldl( 	
		fun(Index, {NewOrderedRing, Parts}) -> 
			Node = lists:nth((Index rem length(Nodes) + 1), Nodes),
			Pile = proplists:get_value(Node, NewOrderedRing),
			Slice = lists:last(Pile),
			CleannedPile = lists:delete(Slice, Pile),
			CleannedOrderedRing = reorder(proplists:delete(Node, NewOrderedRing) ++ [{Node, CleannedPile}],up),
			{CleannedOrderedRing, Parts ++ [Slice]}
		end,
		{OrderedRing,[]},
		lists:seq(0, TotalPartitions - 1)
	),
	Partitions.

-spec update_ring(Ring::ring(), Partitions::list(), NewNodeName::term()) -> ring().	
update_ring(Ring, Partitions, NewNodeName) ->
	UpdatedRing = lists:foldl( 
		fun(PartitionId, NewRing) -> 
			CleannedRing = proplists:delete(PartitionId, NewRing),
			CleannedRing ++ [{PartitionId, NewNodeName}]
		end,
		Ring,
		Partitions
	),
	lists:sort(UpdatedRing).

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

join_ring_joinning_scale_test() ->
	LocalRing = erlCluster_ring:new(16),
	NewRing = erlCluster_ring:join('node2@127.0.0.1', LocalRing),
	Ring = erlCluster_ring:join('node3@127.0.0.1', NewRing),
	?assertEqual(5, length(partitions_node('node1@127.0.0.1', Ring))),
	?assertEqual(5, length(partitions_node('node2@127.0.0.1', Ring))),
	?assertEqual(6, length(partitions_node('node3@127.0.0.1', Ring))).

join_ring_to_many_rings_test() ->
	LocalRing = erlCluster_ring:new(16),
	NewRing = erlCluster_ring:join('node2@127.0.0.1', LocalRing),
	NewRingA = erlCluster_ring:join('node3@127.0.0.1', NewRing),
	Ring = erlCluster_ring:join('node4@127.0.0.1', NewRingA),
	?assertEqual(4, length(partitions_node('node1@127.0.0.1', Ring))),
	?assertEqual(4, length(partitions_node('node2@127.0.0.1', Ring))),
	?assertEqual(4, length(partitions_node('node3@127.0.0.1', Ring))),
	?assertEqual(4, length(partitions_node('node4@127.0.0.1', Ring))).

scale_up_and_down_ring_to_many_rings_test() ->
	LocalRing = erlCluster_ring:new(16),
	NewRing = erlCluster_ring:join('node2@127.0.0.1', LocalRing),
	NewRingA = erlCluster_ring:join('node3@127.0.0.1', NewRing),
	Ring = erlCluster_ring:join('node4@127.0.0.1', NewRingA),
	RingA = erlCluster_ring:leave('node4@127.0.0.1', Ring),
	?assertEqual(5, length(partitions_node('node1@127.0.0.1', RingA))),
	?assertEqual(5, length(partitions_node('node2@127.0.0.1', RingA))),
	?assertEqual(6, length(partitions_node('node3@127.0.0.1', RingA))).

leave_from_two_nodes_ring() ->
	?assertEqual(
		erlCluster_ring:new(8, 'node1@127.0.0.1'), 
		erlCluster_ring:leave('node2@127.0.0.1', fake_ring_bi_node())
	).

total_assigned_partitions_by_node() ->
	Ring = erlCluster_ring:new(16),
	NodeList = erlCluster_ring:nodes(Ring) ++ ['node2@127.0.0.1'],
	?assertEqual(8, total_assigned_partitions(Ring, NodeList)),
	NodeListA = NodeList ++ ['node3@127.0.0.1'],
	?assertEqual(6, total_assigned_partitions(Ring, NodeListA)),
	NodeListB = NodeListA ++ ['node4@127.0.0.1'],
	?assertEqual(4, total_assigned_partitions(Ring, NodeListB)),
	
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

process_ring_to_generate_ordered_ring_test() ->
	?assertEqual(ordered_ring_by_node(), process(fake_ring_bi_node_partitions16())).

reorder_ordered_ring_down_from_minor_to_major_test() ->
	?assertEqual(fake_down_ordered_ring(), reorder(fake_disordered_ring(), down)).

reorder_ordered_ring_up_from_major_to_minor_test() ->
	?assertEqual(lists:reverse(fake_down_ordered_ring()), reorder(fake_disordered_ring(), up)).

pick_partitions_from_ring_test() ->
	Ring = erlCluster_ring:new(16),
	?assertEqual(lists:reverse(pickPartitions(Ring,8)), 
		[730750818665451459101842416358141509827966271488,
		 822094670998632891489572718402909198556462055424,
		 913438523331814323877303020447676887284957839360,
		 1004782375664995756265033322492444576013453623296,
		 1096126227998177188652763624537212264741949407232,
		 1187470080331358621040493926581979953470445191168,
		 1278813932664540053428224228626747642198940975104,
		 1370157784997721485815954530671515330927436759040]).

update_ring_from_single_node_to_double_node_ring() ->
	Ring = erlCluster_ring:new(8),
	Partitions = pickPartitions(Ring,4),
	NewNodeName = 'node2@127.0.0.1', 
	?assertEqual(fake_ring_bi_node(), update_ring(Ring, Partitions, NewNodeName)).

sort_ordered_ring_test() ->
	?assertEqual(
		[{0 ,'node4@127.0.0.1'}, {3 ,'node2@127.0.0.1'}, {5 ,'node1@127.0.0.1'}, {8 ,'node3@127.0.0.1'}]
		, sort_ordered_ring(fake_disordered_ring())
	).

fake_down_ordered_ring() ->
	[{'node4@127.0.0.1', []},
	 {'node2@127.0.0.1',
	 	[456719261665907161938651510223838443642478919680,
		 548063113999088594326381812268606132370974703616,
		 639406966332270026714112114313373821099470487552]
	 },
	{'node1@127.0.0.1',
		[0,
		 91343852333181432387730302044767688728495783936,
		 182687704666362864775460604089535377456991567872,
		 274031556999544297163190906134303066185487351808,
		 365375409332725729550921208179070754913983135744]
	 },
	 {'node3@127.0.0.1',
		[730750818665451459101842416358141509827966271488,
		 822094670998632891489572718402909198556462055424,
		 913438523331814323877303020447676887284957839360,
		 1004782375664995756265033322492444576013453623296,
		 1096126227998177188652763624537212264741949407232,
		 1187470080331358621040493926581979953470445191168,
		 1278813932664540053428224228626747642198940975104,
		 1370157784997721485815954530671515330927436759040]
	 }
	].	

fake_upper_ordered_ring() ->
	[
	 {'node3@127.0.0.1',
		[730750818665451459101842416358141509827966271488,
		 822094670998632891489572718402909198556462055424,
		 913438523331814323877303020447676887284957839360,
		 1004782375664995756265033322492444576013453623296,
		 1096126227998177188652763624537212264741949407232,
		 1187470080331358621040493926581979953470445191168,
		 1278813932664540053428224228626747642198940975104,
		 1370157784997721485815954530671515330927436759040]
	 },
	 {'node1@127.0.0.1',
		[0,
		 91343852333181432387730302044767688728495783936,
		 182687704666362864775460604089535377456991567872,
		 274031556999544297163190906134303066185487351808,
		 365375409332725729550921208179070754913983135744]
	 },
	 {'node2@127.0.0.1',
	 	[456719261665907161938651510223838443642478919680,
		 548063113999088594326381812268606132370974703616,
		 639406966332270026714112114313373821099470487552]
	 },
	 {'node4@127.0.0.1', []}
	].	

fake_disordered_ring() ->
	[{'node1@127.0.0.1',
		[0,
		 91343852333181432387730302044767688728495783936,
		 182687704666362864775460604089535377456991567872,
		 274031556999544297163190906134303066185487351808,
		 365375409332725729550921208179070754913983135744]
	 },
	 {'node2@127.0.0.1',
	 	[456719261665907161938651510223838443642478919680,
		 548063113999088594326381812268606132370974703616,
		 639406966332270026714112114313373821099470487552]
	 },
	 {'node3@127.0.0.1',
		[730750818665451459101842416358141509827966271488,
		 822094670998632891489572718402909198556462055424,
		 913438523331814323877303020447676887284957839360,
		 1004782375664995756265033322492444576013453623296,
		 1096126227998177188652763624537212264741949407232,
		 1187470080331358621040493926581979953470445191168,
		 1278813932664540053428224228626747642198940975104,
		 1370157784997721485815954530671515330927436759040]
	 },
	 {'node4@127.0.0.1', []}
	].

ordered_ring_by_node() ->
	[{'node1@127.0.0.1',
		[0,
		 91343852333181432387730302044767688728495783936,
		 182687704666362864775460604089535377456991567872,
		 274031556999544297163190906134303066185487351808,
		 365375409332725729550921208179070754913983135744,
		 456719261665907161938651510223838443642478919680,
		 548063113999088594326381812268606132370974703616,
		 639406966332270026714112114313373821099470487552]
	 },
	 {'node2@127.0.0.1',
		[730750818665451459101842416358141509827966271488,
		 822094670998632891489572718402909198556462055424,
		 913438523331814323877303020447676887284957839360,
		 1004782375664995756265033322492444576013453623296,
		 1096126227998177188652763624537212264741949407232,
		 1187470080331358621040493926581979953470445191168,
		 1278813932664540053428224228626747642198940975104,
		 1370157784997721485815954530671515330927436759040]
	 }
	].

fake_ring_bi_node() ->
     [{0,'node1@127.0.0.1'},
      {182687704666362864775460604089535377456991567872,'node1@127.0.0.1'},
      {365375409332725729550921208179070754913983135744,'node1@127.0.0.1'},
      {548063113999088594326381812268606132370974703616,'node1@127.0.0.1'},
      {730750818665451459101842416358141509827966271488,'node2@127.0.0.1'},
      {913438523331814323877303020447676887284957839360,'node2@127.0.0.1'},
      {1096126227998177188652763624537212264741949407232,'node2@127.0.0.1'},
      {1278813932664540053428224228626747642198940975104,'node2@127.0.0.1'}].

fake_ring_bi_node_partitions16() ->
    [{0,'node1@127.0.0.1'},
    {91343852333181432387730302044767688728495783936,'node1@127.0.0.1'},
    {182687704666362864775460604089535377456991567872,'node1@127.0.0.1'},
    {274031556999544297163190906134303066185487351808,'node1@127.0.0.1'},
    {365375409332725729550921208179070754913983135744,'node1@127.0.0.1'},
    {456719261665907161938651510223838443642478919680,'node1@127.0.0.1'},
    {548063113999088594326381812268606132370974703616,'node1@127.0.0.1'},
    {639406966332270026714112114313373821099470487552,'node1@127.0.0.1'},
    {730750818665451459101842416358141509827966271488,'node2@127.0.0.1'},
    {822094670998632891489572718402909198556462055424,'node2@127.0.0.1'},
    {913438523331814323877303020447676887284957839360,'node2@127.0.0.1'},
    {1004782375664995756265033322492444576013453623296,'node2@127.0.0.1'},
    {1096126227998177188652763624537212264741949407232,'node2@127.0.0.1'},
    {1187470080331358621040493926581979953470445191168,'node2@127.0.0.1'},
    {1278813932664540053428224228626747642198940975104,'node2@127.0.0.1'},
    {1370157784997721485815954530671515330927436759040,'node2@127.0.0.1'}].