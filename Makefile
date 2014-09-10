.PHONY: rel

all: deps compile

compile: rm_ebin
	./rebar compile

deps:
	./rebar get-deps

clean:
	./rebar clean

start:
	erl -name node1@127.0.0.1 -setcookie thesecretcookie \
	-pa ebin deps/*/ebin -rsh ssh -boot start_sasl -s erlCluster
	
eunit: rm_eunit
	ERL_FLAGS="-name node1@127.0.0.1 -setcookie thesecretcookie -pa ebin deps/*/ebin -rsh ssh" \
	./rebar skip_deps=true compile eunit --verbose

tests: rm_ebin compile
	erl -name node1@127.0.0.1 -setcookie thesecretcookie \
	-pa ebin deps/*/ebin -rsh ssh -eval "eunit:test({application, erlCluster}, [verbose])" -s init stop

rm_ebin:
	rm -rf ebin/

rm_eunit:
	rm -rf .eunit/

restart: rm_ebin compile start