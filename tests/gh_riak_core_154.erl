%% Automated test for issue riak_core#154
%% Hinted handoff does not occur after a node has been restarted in Riak 1.1
-module(gh_riak_core_154).
-export([gh_riak_core_154/0]).
-include_lib("eunit/include/eunit.hrl").

gh_riak_core_154() ->
    Nodes = rt:build_cluster(2),
    [Node1, Node2] = Nodes,

    lager:info("Increase handoff concurrency on nodes"),
    NewConfig = [{riak_core, [{handoff_concurrency, 1024}]}],
    [rt:update_app_config(Node, NewConfig) || Node <- Nodes],

    lager:info("Write data while ~p is offline", [Node2]),
    rt:stop(Node2),
    ?assertEqual([], rt:systest_write(Node1, 1000, 3)),

    lager:info("Verify that ~p is missing data", [Node2]),
    rt:start(Node2),
    rt:stop(Node1),
    ?assertMatch([{_,{error,notfound}}|_],
                 rt:systest_read(Node2, 1000, 3)),

    lager:info("Restart ~p and sleep for 5 min, allowing handoff to occur",
               [Node1]),
    rt:start(Node1),
    timer:sleep(300000),

    lager:info("Verify that ~p has all data", [Node2]),
    rt:stop(Node1),
    ?assertEqual([], rt:systest_read(Node2, 1000, 3)),

    lager:info("gh_riak_core_154: passed"),
    ok.