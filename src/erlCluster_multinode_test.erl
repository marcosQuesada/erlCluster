-module(erlCluster_multinode_test).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).
-include("erlCluster.hrl").

functional_multinode_operations_test_() ->
    {
        foreach,
        fun setup/0,
        fun teardown/1,
        [
            fun multiple_nodes_form_cluster_join_leave_test_working/0
        ]
    }.

setup() ->
    application:ensure_all_started(erlCluster, permanent),
    SlaveA = start_slave(slaveA),
    SlaveB = start_slave(slaveB),
    SlaveC = start_slave(slaveC),
    [SlaveA, SlaveB, SlaveC].

start_slave(Name) ->
    Host = '127.0.0.1',
    Args = " -pa ebin deps/*/ebin -setcookie thesecretcookie -rsh ssh",
    {ok, Slave} = slave:start(Host, Name, Args),
    rpc:call(Slave, application ,ensure_all_started,[erlCluster,permanent]),
    Slave.

teardown([SlaveA, SlaveB, SlaveC]) ->
    slave:stop(SlaveA),
    slave:stop(SlaveB),
    slave:stop(SlaveC),
    application:stop(erlCluster),
    wait_app_for_exit(erlCluster_sup),
    ok.

wait_app_for_exit(Name) ->
    MRef = erlang:monitor(process, whereis(Name)),
    receive
    {'DOWN', MRef, _, _, _} ->
        ok
    end.

multiple_nodes_form_cluster_join_leave_test_working() ->
    Slaves = ['slaveA@127.0.0.1','slaveB@127.0.0.1','slaveC@127.0.0.1'],
    [?assertEqual(pong, net_adm:ping(Slave)) || Slave <- Slaves],
    rpc:call('slaveA@127.0.0.1', erlCluster, join, [node()]),
    timer:sleep(500),
    rpc:call('slaveB@127.0.0.1', erlCluster, join, [node()]),
    timer:sleep(500),
    rpc:call('slaveC@127.0.0.1', erlCluster, join, [node()]),
    timer:sleep(500),
    Ring = erlCluster_node:map_ring(),
    Nodes = erlCluster_ring:nodes(Ring),
    ?assert(lists:member(node(), Nodes)),
    ?assert(lists:member('slaveA@127.0.0.1', Nodes)),
    ?assert(lists:member('slaveB@127.0.0.1', Nodes)),
    ?assert(lists:member('slaveC@127.0.0.1', Nodes)),
    ?assertEqual(4, length(Nodes)),
    
    %% Check partition termination process
    PartitionList = rpc:call('slaveC@127.0.0.1', erlCluster_partition_sup, partition_list, []),
    KilledPartitions = [PartitionId||{PartitionId, Pid} <- PartitionList, Pid =:= undefined],
    ?assertEqual(48, length(KilledPartitions)),
    
    rpc:call('slaveA@127.0.0.1', erlCluster, leave, []),
    timer:sleep(500),
    rpc:call('slaveB@127.0.0.1', erlCluster, leave, []),
    timer:sleep(500),
    rpc:call('slaveC@127.0.0.1', erlCluster, leave, []),
    timer:sleep(500),
    NewRing = erlCluster_node:map_ring(),
    NewNodes = erlCluster_ring:nodes(NewRing),
    ?assertEqual([node()], erlCluster_ring:nodes(NewRing)),
    
    %% check partition recreation
    NewPartitionList = erlCluster_partition_sup:partition_list(),
    NewKilledPartitions = [PartitionId||{PartitionId, Pid} <- NewPartitionList, Pid =:= undefined],
    ?assertEqual(0, length(NewKilledPartitions)).