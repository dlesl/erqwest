%% test suite based on
%% https://github.com/puzza007/katipo/blob/master/test/katipo_SUITE.erl
%% but much less extensive

-module(erqwest_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

init_per_suite(Config) ->
    application:ensure_all_started(erqwest),
    Config.

end_per_suite(_Config) ->
    ok = application:stop(erqwest).

init_per_group(http, Config) ->
  [{client, erqwest:make_client()}|Config];
init_per_group(client_cert, Config) ->
  {ok, #{status := 200, body := Cert}} =
    erqwest:get(erqwest:make_client(), <<"https://badssl.com/certs/badssl.com-client.p12">>),
  [ {cert, Cert}
  , {pass, <<"badssl.com">>}
  | Config].

end_per_group(http, Config) ->
  Config;
end_per_group(client_cert, Config) ->
  Config.

groups() ->
  [ {http, [parallel],
     [ get
     , get_http
     , post
     , timeout
     , redirects
     ]}
  , {client_cert, [],
     [ with_cert
     , without_cert
     ]}
  ].

all() ->
  [ {group, http}
  , {group, client_cert}
  ].

get(Config) ->
  C = ?config(client, Config),
  {ok, #{status := 200, body := Body}} =
    erqwest:get(C, <<"https://httpbin.org/get?a=%21%40%23%24%25%5E%26%2A%28%29_%2B">>),
  #{<<"args">> := #{<<"a">> := <<"!@#$%^&*()_+">>}} = jsx:decode(Body).

get_http(Config) ->
  C = ?config(client, Config),
  {ok, #{status := 200, body := Body}} =
    erqwest:get(C, <<"http://httpbin.org/get?a=%21%40%23%24%25%5E%26%2A%28%29_%2B">>),
  #{<<"args">> := #{<<"a">> := <<"!@#$%^&*()_+">>}} = jsx:decode(Body).

post(Config) ->
  C = ?config(client, Config),
  {ok, #{status := 200, body := Body}} =
    erqwest:post(C, <<"https://httpbin.org/post">>,
                 #{ headers => [{<<"Content-Type">>, <<"application/json">>}]
                  , body => <<"!@#$%^&*()">>}),
  #{<<"data">> := <<"!@#$%^&*()">>} = jsx:decode(Body).

timeout(Config) ->
  C = ?config(client, Config),
  %% TODO: fix this code
  {error, #{code := request}} =
    erqwest:get(C, <<"https://httpbin.org/delay/1">>, #{timeout => 500}).

redirects(_) ->
  {ok, #{status := 302}} =
    erqwest:get(erqwest:make_client(),
                <<"https://nghttp2.org/httpbin/redirect/6">>),
  {ok, #{status := 200}} =
    erqwest:get(erqwest:make_client(#{follow_redirects => true}),
                <<"https://nghttp2.org/httpbin/redirect/6">>),
  %% TODO: fix this code
  {error, #{code := unknown}} =
    erqwest:get(erqwest:make_client(#{follow_redirects => 5}),
                <<"https://nghttp2.org/httpbin/redirect/6">>).

with_cert(Config) ->
  C = erqwest:make_client(#{identity => {?config(cert, Config), ?config(pass, Config)}}),
  {ok, #{status := 200}} = erqwest:get(C, <<"https://client.badssl.com">>).

without_cert(_Config) ->
  C = erqwest:make_client(#{}),
  {ok, #{status := 400}} = erqwest:get(C, <<"https://client.badssl.com">>).
