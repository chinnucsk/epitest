-module(epitest_slave).
-export([start_link/0, start_link/1, start_link/2, stop/1]).
-export([block_call/4, block_call/5]).
-behaviour(gen_server).

-define(SERVER, ?MODULE).

-record(state, { maxid = 0, counter = 0, limit = undefined, waitlist = [] }).

%% API
-export([start_server_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

start_server_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
    Limit = proplists:get_value(max_splitnodes, application:get_all_env(epitest), undefined),
    {ok, #state{limit=Limit}}.

handle_call(incr, From, #state{counter=Counter, limit=Limit}=State0) when Counter == Limit ->
    {noreply, State0#state { waitlist = [From|State0#state.waitlist] } };

handle_call(incr, _From, State0) ->
    State = State0#state{ maxid = State0#state.maxid + 1, counter = State0#state.counter + 1},
    {reply, State#state.maxid, State};

handle_call(decr, _From, State0) ->
    State = State0#state{ maxid = State0#state.maxid + 1, counter = State0#state.counter - 1, waitlist = wtl(State0#state.waitlist)},
    case State0#state.waitlist of
	[H|_T] ->
	    gen_server:reply(H, State#state.maxid);
	_ ->
	    skip
    end,
    {reply, ok, State};

handle_call(_Request, _From, State) ->
    {noreply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% Internal functions
get_path() ->
    lists:map(fun filename:absname/1, code:get_path()).    

start_link() ->
    start_link([]).

start_link(Args) ->
    {_SNodename, Nodename} = generate_nodename(),
    start_link(Nodename, Args).

start_link(Nodename, Args) ->
    {ok, Host} = inet:gethostname(),
    Paths = get_path(),
    {ok, Node} = slave:start_link(list_to_atom(Host), Nodename, "-hidden " ++ Args),
    ok = rpc:call(Node, code, add_paths, [Paths]),
    {ok, Node}.

stop(Node) ->
    gen_server:call(?SERVER, decr),
    slave:stop(Node).

generate_nodename() ->
    S = [$s,$l,$a,$v,$e|erlang:integer_to_list(gen_server:call(?SERVER, incr))],
    {S, erlang:list_to_atom(S)}.


block_call(N,M,F,A) ->
    do_call(N, {block_call,M,F,A,group_leader()}, infinity).

block_call(N,M,F,A,infinity) ->
    do_call(N, {block_call,M,F,A,group_leader()}, infinity);
block_call(N,M,F,A,Timeout) when is_integer(Timeout), Timeout >= 0 ->
    do_call(N, {block_call,M,F,A,group_leader()}, Timeout).

do_call(Node, Request, infinity) ->
    {ok, Pid} = rpc:call(Node, gen_server, start, [rpc,[],[]]),
    Result = rpc_check(catch gen_server:call(Pid, Request, infinity)),
    gen_server:call(Pid, stop, infinity),
    Result;

do_call(Node, Request, Timeout) ->
    Tag = make_ref(),
    {ok, Pid} = rpc:call(Node, gen_server, start, [rpc,[],[]]),
    {Receiver,Mref} =
	erlang:spawn_monitor(
	  fun() ->
		  process_flag(trap_exit, true),
		  Result = gen_server:call(Pid, Request, Timeout),
		  exit({self(),Tag,Result})
	  end),
    receive
	{'DOWN',Mref,_,_,{Receiver,Tag,Result}} ->
	    gen_server:call(Pid, stop, infinity),
	    rpc_check(Result);
	{'DOWN',Mref,_,_,Reason} ->
	    gen_server:call(Pid, stop, infinity),
	    rpc_check_t({'EXIT',Reason})
    end.
rpc_check_t({'EXIT', {timeout,_}}) -> {badrpc, timeout};
rpc_check_t(X) -> rpc_check(X).
	    
rpc_check({'EXIT', {{nodedown,_},_}}) -> {badrpc, nodedown};
rpc_check({'EXIT', X}) -> exit(X);
rpc_check(X) -> X.

wtl([]) ->
    [];
wtl([_H|T]) ->
    T.

