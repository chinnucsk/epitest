-define(EUNIT_NOAUTO, 1).
-include_lib("eunit/include/eunit.hrl").
-import(epitest_helpers, [ok/0, pending/0, pending/1, make_pending/0, make_pending/1, fail/0, fail/1]).

-record(epistate, {
          id, %% test_id()
          test, %% #test{}
          pid, %% pid()
          state :: {'failed', any()} | 'succeeded' | 'undefined' | 'started',
          %%
          handlers_properties = []
         }).

-type test_id() :: any().
-type test_title() :: string().
-type test_argument() :: any().
-type test_loc() :: {module, module(), integer()} | 'dynamic'.
-type test_signature() :: test_title() | {test_title(), list(test_argument())}.
-type test_attribute_name() :: atom().
-type test_attribute_value() :: any().
-type test_property() :: test_attribute_name() | {test_attribute_name(), test_attribute_value()} | test_functor().
-type test_descriptor() :: list(test_property()).
-type test_functor() :: fun(() -> any()) | fun((#epistate{}) -> any()).


-type test_reference() :: string() | {string(), list(test_argument())} | {module(), string()} |
                          {module(), string, list(test_argument())}.

-record(test, {
          id :: test_id(),
          loc :: test_loc(),
          signature :: test_signature(),
          descriptor :: test_descriptor()
       }).
