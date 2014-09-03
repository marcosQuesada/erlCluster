%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Record Data Structures
%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Node Record
-record(node, {
    map_ring,
    status
}).

%% Partition Record
-record(partition, {
    id,
    data,
    status
}).

%% Partition Data Record
-record(data, {
	index
}).


%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Common type definitions
%%%%%%%%%%%%%%%%%%%%%%%%%%

-type node() :: term().
-type ring() :: [{integer(), node()}].


%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Defines
%%%%%%%%%%%%%%%%%%%%%%%%%%

-define(log(Msg, Args), io:format("~p ~p: " ++ Msg, [?MODULE, ?LINE] ++ Args)).
-define(TotalPartitions, 64).
-define(HASHTOP, trunc(math:pow(2,160)-1)). %%forced range