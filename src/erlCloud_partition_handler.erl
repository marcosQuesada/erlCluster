-module(erlCloud_partition_handler).

-behaviour(erlCloud_partition).

-include("erlCloud.hrl").

-export([get/2, set/3, init/1, handle_command/3]).

%% Exported cluster commands
get(Key, Index) ->
	ok.

set(Key, Value, Data) ->
	ok.

init(Id) ->
	ok.

%% Cluster command implementations
handle_command(Cmd, Args, Data) ->
	ok.