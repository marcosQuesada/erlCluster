-module(erlCluster_partition_sup).

-behaviour(supervisor).

%% API
-export([start_link/0, start_partition/1, stop_partition/1, partition_list/0, print_partition_list/0]).

%% Supervisor callbacks
-export([init/1]).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec start_partition(PartitionId::atom()) ->term().
start_partition(PartitionId) -> 
	Child = {PartitionId, {erlCluster_partition, start_link, [PartitionId]}, permanent, 5000, worker, [erlCluster_partition]},
	supervisor:start_child(erlCluster_partition_sup, Child).

-spec stop_partition(PartitionId::atom()) -> term().
stop_partition(PartitionId) ->
	supervisor:terminate_child(erlCluster_partition_sup, PartitionId).

partition_list() ->
	 [{PartitionId, Pid} || {PartitionId, Pid, _, _} <- supervisor:which_children(erlCluster_partition_sup)].

print_partition_list() ->
	[io:format("Partition ~p Pid ~p ~n", [PartitionId, Pid]) || {PartitionId, Pid} <- erlCluster_partition_sup:partition_list()].

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    {ok, {{one_for_one, 10, 10}, []}}.