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
            fun basic_working/0
        ]
    }.

setup() ->
    application:ensure_all_started(erlCluster, permanent),

    Host = '127.0.0.1',
    Args = " -pa ebin deps/*/ebin -setcookie thesecretcookie -rsh ssh",
    {ok, Slave1} = slave:start(Host, slave1, Args),

    rpc:call(Slave1, application ,ensure_all_started,[erlCluster,permanent]),
    ?assertEqual(pong, net_adm:ping(Slave1)),
    ?assertEqual(Slave1, 'slave1@127.0.0.1'),
    [Slave1].

teardown([Slave1]) ->
    slave:stop(Slave1),
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
    ?assert(true).