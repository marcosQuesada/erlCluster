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
            fun basic_command_handling/0,
            fun basic_two_nodes_join/0
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

basic_two_nodes_join() ->
    Slave = 'slave@127.0.0.1',
    ?assertEqual(pong, net_adm:ping(Slave)),
    %RingS1 = rpc:call(Slave, erlCluster_ring, get_ring, []),
    erlCluster:join(Slave),
    timer:sleep(300), %% Required to allow synchronization to remote node
    ?assertEqual(real_bi_ring(), erlCluster_node:map_ring()).

real_bi_ring() ->
    [{0,'slave@127.0.0.1'},
     {22835963083295358096932575511191922182123945984,
      'slave@127.0.0.1'},
     {45671926166590716193865151022383844364247891968,
      'slave@127.0.0.1'},
     {68507889249886074290797726533575766546371837952,
      'slave@127.0.0.1'},
     {91343852333181432387730302044767688728495783936,
      'slave@127.0.0.1'},
     {114179815416476790484662877555959610910619729920,
      'slave@127.0.0.1'},
     {137015778499772148581595453067151533092743675904,
      'slave@127.0.0.1'},
     {159851741583067506678528028578343455274867621888,
      'slave@127.0.0.1'},
     {182687704666362864775460604089535377456991567872,
      'slave@127.0.0.1'},
     {205523667749658222872393179600727299639115513856,
      'slave@127.0.0.1'},
     {228359630832953580969325755111919221821239459840,
      'slave@127.0.0.1'},
     {251195593916248939066258330623111144003363405824,
      'slave@127.0.0.1'},
     {274031556999544297163190906134303066185487351808,
      'slave@127.0.0.1'},
     {296867520082839655260123481645494988367611297792,
      'slave@127.0.0.1'},
     {319703483166135013357056057156686910549735243776,
      'slave@127.0.0.1'},
     {342539446249430371453988632667878832731859189760,
      'slave@127.0.0.1'},
     {365375409332725729550921208179070754913983135744,
      'slave@127.0.0.1'},
     {388211372416021087647853783690262677096107081728,
      'slave@127.0.0.1'},
     {411047335499316445744786359201454599278231027712,
      'slave@127.0.0.1'},
     {433883298582611803841718934712646521460354973696,
      'slave@127.0.0.1'},
     {456719261665907161938651510223838443642478919680,
      'slave@127.0.0.1'},
     {479555224749202520035584085735030365824602865664,
      'slave@127.0.0.1'},
     {502391187832497878132516661246222288006726811648,
      'slave@127.0.0.1'},
     {525227150915793236229449236757414210188850757632,
      'slave@127.0.0.1'},
     {548063113999088594326381812268606132370974703616,
      'slave@127.0.0.1'},
     {570899077082383952423314387779798054553098649600,
      'slave@127.0.0.1'},
     {593735040165679310520246963290989976735222595584,
      'slave@127.0.0.1'},
     {616571003248974668617179538802181898917346541568,
      'slave@127.0.0.1'},
     {639406966332270026714112114313373821099470487552,
      'slave@127.0.0.1'},
     {662242929415565384811044689824565743281594433536,
      'slave@127.0.0.1'},
     {685078892498860742907977265335757665463718379520,
      'slave@127.0.0.1'},
     {707914855582156101004909840846949587645842325504,
      'slave@127.0.0.1'},
     {730750818665451459101842416358141509827966271488,
      'node1@127.0.0.1'},
     {753586781748746817198774991869333432010090217472,
      'node1@127.0.0.1'},
     {776422744832042175295707567380525354192214163456,
      'node1@127.0.0.1'},
     {799258707915337533392640142891717276374338109440,
      'node1@127.0.0.1'},
     {822094670998632891489572718402909198556462055424,
      'node1@127.0.0.1'},
     {844930634081928249586505293914101120738586001408,
      'node1@127.0.0.1'},
     {867766597165223607683437869425293042920709947392,
      'node1@127.0.0.1'},
     {890602560248518965780370444936484965102833893376,
      'node1@127.0.0.1'},
     {913438523331814323877303020447676887284957839360,
      'node1@127.0.0.1'},
     {936274486415109681974235595958868809467081785344,
      'node1@127.0.0.1'},
     {959110449498405040071168171470060731649205731328,
      'node1@127.0.0.1'},
     {981946412581700398168100746981252653831329677312,
      'node1@127.0.0.1'},
     {1004782375664995756265033322492444576013453623296,
      'node1@127.0.0.1'},
     {1027618338748291114361965898003636498195577569280,
      'node1@127.0.0.1'},
     {1050454301831586472458898473514828420377701515264,
      'node1@127.0.0.1'},
     {1073290264914881830555831049026020342559825461248,
      'node1@127.0.0.1'},
     {1096126227998177188652763624537212264741949407232,
      'node1@127.0.0.1'},
     {1118962191081472546749696200048404186924073353216,
      'node1@127.0.0.1'},
     {1141798154164767904846628775559596109106197299200,
      'node1@127.0.0.1'},
     {1164634117248063262943561351070788031288321245184,
      'node1@127.0.0.1'},
     {1187470080331358621040493926581979953470445191168,
      'node1@127.0.0.1'},
     {1210306043414653979137426502093171875652569137152,
      'node1@127.0.0.1'},
     {1233142006497949337234359077604363797834693083136,
      'node1@127.0.0.1'},
     {1255977969581244695331291653115555720016817029120,
      'node1@127.0.0.1'},
     {1278813932664540053428224228626747642198940975104,
      'node1@127.0.0.1'},
     {1301649895747835411525156804137939564381064921088,
      'node1@127.0.0.1'},
     {1324485858831130769622089379649131486563188867072,
      'node1@127.0.0.1'},
     {1347321821914426127719021955160323408745312813056,
      'node1@127.0.0.1'},
     {1370157784997721485815954530671515330927436759040,
      'node1@127.0.0.1'},
     {1392993748081016843912887106182707253109560705024,
      'node1@127.0.0.1'},
     {1415829711164312202009819681693899175291684651008,
      'node1@127.0.0.1'},
     {1438665674247607560106752257205091097473808596992,
      'node1@127.0.0.1'}].
