-module(erlCluster_functional_test).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).
-include("erlCluster.hrl").

functional_partition_test_() ->
    {
        foreach,
        fun setup/0,
        fun teardown/1,
        [
            fun basic_working/0,
            fun basic_command_handling/0
        ]
    }.

setup() ->
    application:ensure_all_started(erlCluster, permanent),
    Slave = start_slave(),
    [Slave].

start_slave() ->
    Host = '127.0.0.1',
    Args = " -pa ebin deps/*/ebin -setcookie thesecretcookie -rsh ssh",
    {ok, Slave} = slave:start(Host, slave, Args),
    rpc:call(Slave, application ,ensure_all_started,[erlCluster,permanent]),
    Slave.

teardown([Slave]) ->
    slave:stop(Slave),
    application:stop(erlCluster),
    wait_app_for_exit(erlCluster_sup),
    ok.

wait_app_for_exit(Name) ->
    MRef = erlang:monitor(process, whereis(Name)),
    receive
    {'DOWN', MRef, _, _, _} ->
        ok
    end.

basic_working() ->
    ?assertEqual(pong, net_adm:ping('slave@127.0.0.1')).

basic_command_handling() ->
    [erlCluster:set(Value, Value) || Value <- lists:seq(0,50000)],
    [?assertEqual(Value, erlCluster:get(Value)) || Value <- lists:seq(0,50000)].
