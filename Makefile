VSN=$(shell git log --pretty=format:%h -n 1)
MAKEARG=[{d,vsn,\"${VSN}\"}]
PWD=$(shell pwd)

all: ebin/epitest.app

ebin/epitest.app: ebin/epitest.app.src compile
	@cat ebin/epitest.app.src | sed s/%vsn%/$(VSN)/g > ebin/epitest.app

compile:
	@erl -pa ebin -noshell -eval "make:all($(MAKEARG))" -s erlang halt

selftest: compile
	@erl -noshell -pa t ebin -s epitest -eval "epitest:add_module(selftest)" -s epitest run 

clean:
	rm -rf ebin/*.app ebin/*.beam

vsn:
	@echo $(VSN)
