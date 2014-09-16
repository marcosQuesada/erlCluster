-module(erlCluster_node).

-include("erlCluster.hrl").

-behaviour(gen_fsm).

%% API
-export([start_link/0, map_ring/0, join/1, leave/0, command/3]).

%% Partiton FSM states
-export([booting/2, joinning/2,joinning/3, 
         leaving/2, leaving/3, running/2, running/3]).

%% gen_fsm callbacks
-export([init/1, handle_event/3,handle_sync_event/4, handle_info/3, 
		terminate/3, code_change/4]).

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link() -> ok,Pid} | ignore | {error,Error}
%% Description:Creates a gen_fsm process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this function
%% does not return until Module:init/1 has returned.
%%--------------------------------------------------------------------
start_link() ->
  gen_fsm:start_link({global, {node, node()}}, ?MODULE, [], []).

%% Command to a dedicated Key (Args equals Cmd(Args))
command(PartitionId, Node, Args) ->
  gen_fsm:sync_send_all_state_event({global, {node, Node}}, {cmd, PartitionId, Args}).

map_ring() ->
	gen_fsm:sync_send_all_state_event({global, {node, node()}}, map_ring).

join(Node) ->
  gen_fsm:sync_send_event({global, {node, node()}}, {join, Node}). 

leave() ->
  gen_fsm:sync_send_event({global, {node, node()}}, leave). 
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
init([]) ->
  {ok, booting, #node{
    map_ring = erlCluster_ring:new(?TotalPartitions),
    status = booting
  }, 0}.

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
booting(_Event, State) ->
  io:format("Initializing Partitions ~n", []),
  Ring = State#node.map_ring,
  [erlCluster_partition:start_link(PartitionId) || {PartitionId, _ } <- Ring],
  {next_state, running, State}.

joinning(_Event, State) ->
  io:format("On joinning state, asynch event function ~n", []),
  %% Synchro all cluster node state
  NewRing = erlCluster_ring:join('foo@127.0.0.1', State#node.map_ring),
  io:format("New Ring is ~p ~n", [NewRing]), 
  {next_state, running, State#node{map_ring = NewRing}, 0}.

leaving(_Event, State) ->
  io:format("On leaving state, asynch event function ~n", []),
  NewRing = erlCluster_ring:leave('foo@127.0.0.1', State#node.map_ring),
  io:format("New Ring is ~p ~n", [NewRing]), 
  {next_state, running, State#node{map_ring = NewRing}, 0}.

running({join, Node}, State) ->
  io:format("On running state, join to Node ~p ~n", [Node]),
  {next_state, joinning, State};

running(leave, State) ->
  io:format("On running state, asynch event function ~n", []),
  {next_state, leaving, State};

running(_Event, State) ->
  io:format("On running state, asynch event function ~n", []),
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
    io:format("On joinning state, Synchronous call ~n", []),
    %% Synchro all cluster node state
    Ring = State#node.map_ring,
    NewRing = erlCluster_ring:join('foo@127.0.0.1', Ring),
    io:format("New Ring is ~p ~n", [NewRing]),
    {next_state, running, State#node{map_ring = NewRing}, 0}.

leaving(_Event, _From, State) ->
    Reply = ok,
    {reply, Reply, leaving, State}.

running({join, Node}, _From, State) ->
    io:format("Switching to joinning state, joining Node ~p ~n", [Node]),
    Reply = ok,
    {reply, Reply, joinning, State, 0};

running(leave, _From, State) ->
    io:format("Switching to joinning state, synch event function ~n", []),
    Reply = ok,
    {reply, Reply, leaving, State, 0};

running(_Event, _From, State) ->
    io:format("On running state ~n", []),
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
handle_sync_event({join, Node}, _From, StateName, State) ->

  {reply, {ok, Node}, StateName, State};

handle_sync_event(leave, _From, StateName, State) ->
  {reply, ok, StateName, State};

handle_sync_event(map_ring, _From, StateName, State) ->
  {reply, State#node.map_ring, StateName, State};

handle_sync_event({cmd, PartitionId, [Cmd|Args]}, _From, StateName, State) ->
  Result = erlCluster_partition:handle_command(PartitionId, Cmd, Args),
  {reply, Result, StateName, State};

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
