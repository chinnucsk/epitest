-module(epitest_test_server).
-behaviour(gen_server).

-export([add/2, add/3, lookup/1, load/1]).

-include_lib("epitest/include/epitest.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {
          tests
         }).


-define(SERVER, {?MODULE, cluster_name()}).

start_link() ->
    gen_server:start_link({global, ?SERVER}, ?MODULE, [], []).

init([]) ->
    {ok, #state{
       tests = ets:new(epitest_tests, [public, {keypos, 2}])
      }}.

handle_call({add, Loc, Signature, Descriptor}, _From, #state{ tests = Tests } = State) ->
    ID = make_ref(),
    ets:insert(Tests, #test{ id = ID, loc = Loc, signature = Signature, descriptor = Descriptor}),
    {reply, {ok, ID}, State};

handle_call({lookup, ID}, _From, #state{ tests = Tests } = State) ->
    case ets:lookup(Tests, ID) of
        [] ->
            {reply, {error, notfound}, State};
        [Test] ->
            {reply, Test, State}
    end;

handle_call({load, Module}, From, State) ->
    spawn_link(fun () ->
                       Signatures = epitest_beam:signatures(Module),
                       Replies = [ add({module, Module, Loc}, Signature, apply(Module, test, [Signature])) ||
                                     {Loc, Signature} <- Signatures ],
                       gen_server:reply(From, {ok, lists:map(fun ({ok, Reply}) -> Reply;
                                                            ({error, _} = Error) -> Error
                                                        end, Replies)})
               end),
    {noreply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% Public functions
-spec add(test_signature(), test_descriptor()) -> {'ok', test_id()} | {'error', any()}.
add(Signature, Descriptor) ->
    add(dynamic, Signature, Descriptor).

-spec add(test_loc(), test_signature(), test_descriptor()) -> {'ok', test_id()} | {'error', any()}.
                  
add(Loc, Signature, Descriptor) ->
    gen_server:call({global, ?SERVER}, {add, Loc, Signature, Descriptor}).

-spec lookup(test_id()) -> #test{} | {'error', any()}.

lookup(ID) ->
    gen_server:call({global, ?SERVER}, {lookup, ID}).

-spec load(module()) -> {'ok', list(test_id())} | {'error', any()}.

load(Module) ->
    gen_server:call({global, ?SERVER}, {load, Module}).


%% Internal functions
cluster_name() ->
    proplists:get_value(cluster_name, application:get_all_env(epitest), default).
