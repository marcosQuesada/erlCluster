-module(erlCluster_node).

-include("erlCluster.hrl").

-behaviour(gen_fsm).
-export([start_link/0, map_ring/0,map_ring/1, join/1, leave/0, handle_command/2, distribute/2, migrate/2]).

%% Partiton FSM states
-export([booting/2, joinning/2,joinning/3, 
         leaving/2, leaving/3, running/2, running/3]).

%% gen_fsm callbacks
-export([init/1, handle_event/3,handle_sync_event/4, handle_info/3, 
    terminate/3, code_change/4]).

-include_lib("eunit/include/eunit.hrl").
%% API
%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link() -> ok,Pid} | ignore | {error,Error}
%% Description:Creates a gen_fsm process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this function
%% does not return until Module:init/1 has returned.
%%--------------------------------------------------------------------
-spec start_link() -> {ok,pid()} | ignore | {error,term()}.
start_link() ->
  gen_fsm:start_link({global, {node, node()}}, ?MODULE, [], []).

%% handle_command to a dedicated Key (Args equals {Cmd,Arg, ...}))
-spec handle_command(Key::term(), Args::term()) -> term().
handle_command(Key, Args) ->
  Ring = erlCluster_node:map_ring(),
  {PartitionId, Node} = erlCluster_ring:partition(Key, Ring),

  gen_fsm:sync_send_all_state_event({global, {node, Node}}, {cmd, list_to_atom(integer_to_list(PartitionId)), Args}).

-spec map_ring() -> ring().
map_ring() ->
  map_ring(node()).

-spec map_ring(Node::atom()) -> ring().
map_ring(Node) ->
	  gen_fsm:sync_send_all_state_event({global, {node, Node}}, map_ring).

-spec join(Node::atom()) -> term().
join(Node) ->
    gen_fsm:sync_send_event({global, {node, node()}}, {join, Node}). 

-spec leave() -> term().
leave() ->
    gen_fsm:sync_send_event({global, {node, node()}}, leave). 

-spec distribute(DestNode::atom(), NewRing::ring()) -> term().
distribute(DestNode, NewRing) ->
    gen_fsm:sync_send_all_state_event({global, {node, DestNode}}, {propagate, NewRing}). 

migrate(PartitionId, DestNode) ->
    AtomPartitionId = list_to_atom(integer_to_list(PartitionId)),
    PartitionData = erlCluster_partition:content(AtomPartitionId),
    {Size, _} = erlCluster_partition_handler:handle_command(size, PartitionData),
    case Size of
        0 ->
            ok;
        _ ->
            gen_fsm:send_all_state_event({global, {node, DestNode}}, {migrate, PartitionId, PartitionData})
    end.
            
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
    Ring = State#node.map_ring,
    initialize_partitions(Ring),
    {next_state, running, State}.

joinning(_Event, State = #node{remote_node = Node, map_ring = OldRing}) ->
    %% Synchro all cluster node state
    RemoteRing = erlCluster_node:map_ring(Node),
    NewRing = erlCluster_ring:join(node(), RemoteRing),
    %%order distribute on remote cluster nodes
    propagate(NewRing),
    %% handle local partitions from inside process
    handle_partitions(NewRing, State#node.map_ring),    
    {next_state, running, State#node{map_ring = NewRing, remote_node = ''}, 0}.

leaving(_Event, State = #node{map_ring = OldRing}) ->
    NewRing = erlCluster_ring:leave(node(), OldRing),
    propagate(NewRing),
    {next_state, running, State#node{status = leaved}, 0}.

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
    {reply, ok, running, State}.

leaving(_Event, _From, State) ->
    {reply, ok, leaving, State}.

running({join, Node}, _From, State) ->
    case net_adm:ping(Node) of
        pong ->
            case global:whereis_name({node, Node}) of
                undefined ->
                    {reply, {Node, not_registered}, running, State};
                _ ->
                    {reply, ok, joinning, State#node{remote_node = Node}, 200}
            end;
        Other ->
            {reply, {Node, not_reachable}, running, State}
    end;

running(leave, _From, State) ->
    {reply, ok, leaving, State, 0};

running(_Event, _From, State) ->
  	{reply, ok, running, State}.
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
handle_event({migrate, PartitionId, PartitionData}, StateName, State) ->
    erlCluster_partition:set_data(list_to_atom(integer_to_list(PartitionId)), PartitionData),
    {next_state, StateName, State};

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

handle_sync_event({propagate,NewRing}, _From, StateName, State) ->
    handle_partitions(NewRing, State#node.map_ring),
    {reply, ok, StateName, State#node{map_ring = NewRing}};

handle_sync_event({cmd, PartitionId, Args}, _From, StateName, State) ->
    Result = erlCluster_partition:handle_command(PartitionId, Args),
    {reply, Result, StateName, State};

handle_sync_event(_Event, _From, StateName, State) ->
    {reply, ok, StateName, State}.

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
-spec initialize_partitions(Ring::ring()) -> term().
initialize_partitions(Ring) ->
    lists:foreach( 
        fun({PartitionId, _}) ->
            erlCluster_partition_sup:start_partition(list_to_atom(integer_to_list(PartitionId)))
        end,
    Ring
    ).

-spec propagate(NewRing::ring()) -> term().
propagate(NewRing) ->
    NodeList = lists:delete(node(), erlCluster_ring:nodes(NewRing)),
    [distribute(DestNode, NewRing) ||DestNode <- NodeList].
  
-spec handle_partitions(NewRing::ring(), OldRing::ring()) -> term().
handle_partitions(NewRing, OldRing) ->
    [{leave, LeavingPartitions}, {new, IncommingPartitions}] = erlCluster_ring:difference(NewRing, OldRing),
    %% Ensure New Partitions exists
    lists:foreach( 
        fun(PartitionId) ->
            AtomPartitionId = list_to_atom(integer_to_list(PartitionId)),
            case whereis(AtomPartitionId) of
              undefined ->
                  erlCluster_partition_sup:start_partition(AtomPartitionId);
              Pid ->
                  ok
            end            
        end,
    IncommingPartitions
    ),
    %% Handle leaving partitions
    lists:foreach( 
        fun(PartitionId) ->
            %% Migrate content from partitions before stop it
            DestNode = erlCluster_ring:partition_owner(PartitionId, NewRing),
            erlCluster_node:migrate(PartitionId, DestNode),
            erlCluster_partition_sup:stop_partition(list_to_atom(integer_to_list(PartitionId)))
        end,
    LeavingPartitions
    ),
    ok.