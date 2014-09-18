-module(erlCluster_partition_sup).

-behaviour(supervisor).

%% API
-export([start_link/0, start_partition/1]).

%% Supervisor callbacks
-export([init/1]).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_partition(PartitionId) when is_integer(PartitionId) -> 
	Name = list_to_atom("erlCluster_partition_" ++ integer_to_list(PartitionId)),
	Child = {Name, {erlCluster_partition, start_link, [PartitionId]}, permanent, 5000, worker, [erlCluster_partition]},
	supervisor:start_child(erlCluster_partition_sup, Child).
	
%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    {ok, {{one_for_one, 10, 10}, []}}.


