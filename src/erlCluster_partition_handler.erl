-module(erlCluster_partition_handler).

-behaviour(erlCluster_partition).

-include("erlCluster.hrl").

-export([init/0, handle_command/3]).

%% Set partition Data Structure
-spec init() -> data().
init() ->
	#data{index = dict:new()}.

%% Cluster command implementations
%-spec handle_command(Cmd::atom(), Args::list(), Data::data()) -> {ok, term()} | {error, term()}.
handle_command(get, [Key], Data) ->
	dict:find(Key, Data#data.index);
	
handle_command(set, [Key, Value], Data) ->
	NewDict = dict:append(Key, Value, Data#data.index),
	#data{index = NewDict};

handle_command(_Cmd, _Args, _Data) ->
	{ok, no_command_handler}.
