-module(erater_group).
-behavior(gen_server).

-export([start_link/2]).
-export([configure/2, get_config/1, get_config/2, status/1]).

-export([init/1, terminate/2, code_change/3]).
-export([handle_call/3, handle_cast/2, handle_info/2]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% API
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
start_link(Name, Config) when is_atom(Name), is_list(Config) ->
    gen_server:start_link({local, Name}, ?MODULE, [Name, Config], []).

configure(Group, Config) ->
    gen_server:call(Group, {configure, Config}).

get_config(Group) ->
    ets:tab2list(Group).

get_config(Group, Key) ->
    ets:lookup_element(Group, Key, 2).

status(Group) when is_atom(Group) ->
    get_group_status(Group).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% gen_server
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-record(group, {
        name,
        config
        }).

init([Name, Config]) ->
    Name = ets:new(Name, [set, public, named_table, {read_concurrency, true}]),
    save_config(Name, Config),
    State = #group{name = Name, config = Config},
    {ok, State}.

handle_call(_, _, State) ->
    {reply, {error, not_implemented}, State}.

handle_cast(_, State) ->
    {noreply, State}.

handle_info(_, State) ->
    {noreply, State}.

terminate(_, _) ->
    ok.

code_change(_, State, _) ->
    {ok, State}.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Internals
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
save_config(Name, Config) ->
    true = ets:insert(Name, erater_config:clean(Config)),
    ok.

get_group_status(Group) ->
    AllNodes = [node() | nodes()],
    ActiveNodes = [{Node, Shard} || {Shard, Node} <- erater_shard:map(Group)],
    NodesToExamine = [Node || Node <- AllNodes, not lists:keymember(Node, 1, ActiveNodes)],
    StandbyNodes = [{Node, standby} || Node <- NodesToExamine, node_has_group(Node, Group)],
    lists:keysort(1, ActiveNodes ++ StandbyNodes).

node_has_group(Node, Group) ->
    case rpc:call(Node, erater_group, get_config, [Group, shards]) of
        {badrpc, _} -> false;
        undefined -> false;
        Shards when is_integer(Shards) -> true
    end.
