/* Grammar for test_cpp_state.cc: threaded state from C++ actions. */
{
#include "dparse.hpp"
#include <string>
extern std::string cpp_state_trace;
static int depth(void *s) { const int *d = dparser::state<int>(s); return d ? *d : 0; }
}

program: stmt* | 'b' alt ;
stmt: 'while' enter stmt leave
    | 'break' [ if (!depth(${state})) ${reject}; ]
    | 'x' ;
enter: [ ${state} = dparser::make_state(${parser}, depth(${state}) + 1); ] ;
leave: [ ${state} = dparser::make_state(${parser}, depth(${state}) - 1); ] ;

/* Two parses of 'b c' that end with different states. */
alt: 'c' [ ${state} = dparser::make_state(${parser}, 1); ] { cpp_state_trace += "one"; }
   | 'c' [ ${state} = dparser::make_state(${parser}, 2); ] { cpp_state_trace += "two"; } ;
