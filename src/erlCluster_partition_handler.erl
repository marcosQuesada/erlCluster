-module(erlCluster_partition_handler).

-behaviour(erlCluster_partition).

-include("erlCluster.hrl").

-export([init/0, handle_command/2, is_empty/1]).

%% Partition Data Record
-record(data, {
	index :: dict()
}).

-define(DATA, #data{} ).
-type data() :: ?DATA.

%% Set partition Data Structure
-spec init() -> data().
init() ->
	#data{index = dict:new()}.

%% Cluster command implementations
-spec handle_command(term(), Data::data()) -> {term(), data()} | {error, data()}.
handle_command(size, Data) ->
	Result = dict:size(Data#data.index),
	{Result, Data};

handle_command({get, Key}, Data) ->
	Result = case dict:find(Key, Data#data.index) of
		{ok, Reply} ->
			hd(Reply);
		error ->
			key_not_found
	end,
	{Result, Data};
	
handle_command({set, Key, Value}, Data) ->
	NewDict = dict:append(Key, Value, Data#data.index),
	{ok, #data{index = NewDict}};

handle_command(_Args, _Data) ->
	{ok, no_command_handler}.

-spec is_empty(Data::data()) -> integer().
is_empty(Data) ->
	%%dict:is_empty(Data#data.index).
	dict:size(Data#data.index) =:= 0.