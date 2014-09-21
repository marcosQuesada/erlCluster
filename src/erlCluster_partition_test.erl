-module(erlCluster_partition_test).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).
-include("erlCluster.hrl").

functional_partition_test_() ->
    {
        foreach,
        fun setup/0,
        fun teardown/1,
        [
            fun is_empty_feature/0,
            fun standard_status/0
        ]
    }.

setup() ->
    application:set_env(erlCluster, partition_handler, erlCluster_partition_handler),
	{ok, Pid} = erlCluster_partition:start_link('0'),
    [Pid].

teardown([Pid]) ->
	erlCluster_partition:stop('0'),
    wait_app_for_exit(Pid),
    ok.

wait_app_for_exit(Pid) ->
    MRef = erlang:monitor(process, Pid),
    receive
    {'DOWN', MRef, _, _, _} ->
        ok
    end.

is_empty_feature() ->
    ?assert(erlCluster_partition:is_empty('0')).

standard_status() ->
    {Status, _} = erlCluster_partition:status('0'), 
    ?assertEqual(running, Status).
