-module(erlCluster_partition).

-include("erlCluster.hrl").

-behaviour(gen_fsm).

%% API
-export([start_link/1, handle_command/2, is_empty/1, stop/1, status/1]).

%% Partiton FSM states
-export([joinning/2,joinning/3, leaving/2, leaving/3, running/2, running/3]).

%% gen_fsm callbacks
-export([init/1, handle_event/3,handle_sync_event/4, handle_info/3, 
		terminate/3, code_change/4]).

%% Data structure to be decleared on handler
-type data() :: term().

-callback init() -> data().
-callback handle_command(CmdArgs::term(),Data::data()) -> {term(), data()} | {error, data()}.
-callback is_empty(Data::data()) -> boolean().

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link() -> ok,Pid} | ignore | {error,Error}
%% Description:Creates a gen_fsm process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this function
%% does not return until Module:init/1 has returned.
%%--------------------------------------------------------------------
-spec start_link(PartitionId::atom()) -> {ok, pid()}.
start_link(PartitionId) ->
  {ok, Handler} = application:get_env(erlCluster, partition_handler),  
  gen_fsm:start_link({local, PartitionId}, ?MODULE, [PartitionId, Handler], []).

-spec handle_command(PartitionId::atom(), Args::list()) -> term().
handle_command(PartitionId, Args) ->
  gen_fsm:sync_send_all_state_event(PartitionId, {command, Args}).

-spec is_empty(PartitionId::atom()) -> boolean().
is_empty(PartitionId) ->
  gen_fsm:sync_send_all_state_event(PartitionId, is_empty).

-spec stop(PartitionId::atom()) -> term().
stop(PartitionId) ->
  gen_fsm:sync_send_all_state_event(PartitionId, stop).

-spec status(PartitionId::atom()) -> running | joinning | leaving.
status(PartitionId) ->
  gen_fsm:sync_send_all_state_event(PartitionId, status).

%%====================================================================
%% gen_fsm callbacks
%%====================================================================
%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, StateName, State} |
%%                         {ok, StateName, State, Timeout} |
%%                         ignore                              |
%%                         {stop, StopReason}
%% Description:Whenever a gen_fsm is started using gen_fsm:start/[3,4] or
%% gen_fsm:start_link/3,4, this function is called by the new process to
%% initialize.
%%--------------------------------------------------------------------
init([PartitionId, Module]) ->
  {ok, running, #partition{
    id = PartitionId,
    handler = Module,
    data = Module:init(),
    status = initializing
  }}.

%%--------------------------------------------------------------------
%% Function:
%% state_name(Event, State) -> {next_state, NextStateName, NextState}|
%%                             {next_state, NextStateName,
%%                                NextState, Timeout} |
%%                             {stop, Reason, NewState}
%% Description:There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_event/2, the instance of this function with the same name as
%% the current state name StateName is called to handle the event. It is also
%% called if a timeout occurs.
%%--------------------------------------------------------------------
joinning(_Event, State) ->
  {next_state, joinning, State}.

leaving(_Event, State) ->
  {next_state, leaving, State}.

running(_Event, State) ->
  {next_state, running, State}.
%%--------------------------------------------------------------------
%% Function:
%% state_name(Event, From, State) -> {next_state, NextStateName, NextState} |
%%                                   {next_state, NextStateName,
%%                                     NextState, Timeout} |
%%                                   {reply, Reply, NextStateName, NextState}|
%%                                   {reply, Reply, NextStateName,
%%                                    NextState, Timeout} |
%%                                   {stop, Reason, NewState}|
%%                                   {stop, Reason, Reply, NewState}
%% Description: There should be one instance of this function for each
%% possible state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_event/2,3, the instance of this function with the same
%% name as the current state name StateName is called to handle the event.
%%--------------------------------------------------------------------
joinning(_Event, _From, State) ->
    Reply = ok,
  	{reply, Reply, joinning, State}.

leaving(_Event, _From, State) ->
    Reply = ok,
  	{reply, Reply, leaving, State}.

running(_Event, _From, State) ->
	Reply = ok,
  	{reply, Reply, running, State}.
%%--------------------------------------------------------------------
%% Function:
%% handle_event(Event, StateName, State) -> {next_state, NextStateName,
%%                                                NextState} |
%%                                          {next_state, NextStateName,
%%                                                NextState, Timeout} |
%%                                          {stop, Reason, NewState}
%% Description: Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_all_state_event/2, this function is called to handle
%% the event.
%%--------------------------------------------------------------------
handle_event(_Event, StateName, State) ->
  {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% Function:
%% handle_sync_event(Event, From, StateName,
%%                   State) -> {next_state, NextStateName, NextState} |
%%                             {next_state, NextStateName, NextState,
%%                              Timeout} |
%%                             {reply, Reply, NextStateName, NextState}|
%%                             {reply, Reply, NextStateName, NextState,
%%                              Timeout} |
%%                             {stop, Reason, NewState} |
%%                             {stop, Reason, Reply, NewState}
%% Description: Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_all_state_event/2,3, this function is called to handle
%% the event.
%%--------------------------------------------------------------------
handle_sync_event({command, Args}, _From, StateName, State = #partition{handler = Module, data = Data}) ->
  {Result, NewData} = Module:handle_command(Args, Data),
  {reply, Result, StateName, State#partition{data = NewData}};

handle_sync_event(is_empty, _From, StateName, State = #partition{handler = Module, data = Data}) ->
  Result = Module:is_empty(Data),
  {reply, Result, StateName, State};

handle_sync_event(stop, _From, _StateName, State) ->
  {stop, normal, ok, State};

handle_sync_event(status, _From, StateName, State) ->
  {reply, {StateName, State}, StateName, State};

handle_sync_event(_Event, _From, StateName, State) ->
  Reply = ok,
  {reply, Reply, StateName, State}.

%%--------------------------------------------------------------------
%% Function:
%% handle_info(Info,StateName,State)-> {next_state, NextStateName, NextState}|
%%                                     {next_state, NextStateName, NextState,
%%                                       Timeout} |
%%                                     {stop, Reason, NewState}
%% Description: This function is called by a gen_fsm when it receives any
%% other message than a synchronous or asynchronous event
%% (or a system message).
%%--------------------------------------------------------------------
handle_info(_Info, StateName, State) ->
  {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, StateName, State) -> void()
%% Description:This function is called by a gen_fsm when it is about
%% to terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_fsm terminates with
%% Reason. The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, _StateName, _State) ->
  ok.

%%--------------------------------------------------------------------
%% Function:
%% code_change(OldVsn, StateName, State, Extra) -> {ok, StateName, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, StateName, State, _Extra) ->
  {ok, StateName, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
