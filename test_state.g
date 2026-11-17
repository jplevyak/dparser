/* Grammar for test_state.c: threaded state (${state}).  Each test uses its
   own start symbol; make_dparser -A builds states for all of them.  State
   values are ints made by st_make (see test_state.c). */
{
#include <string.h>
void *st_make(int v);
int st_val(void *s);
extern char st_trace[256];
static void trace(const char *s) { strncat(st_trace, s, sizeof(st_trace) - strlen(st_trace) - 1); }
}

/* break is legal only inside a loop: the state is the loop depth. */
loop_program: stmt* ;
stmt: 'while' '(' 'x' ')' enter stmt leave
    | 'break' ';' [ if (st_val(${state}) == 0) ${reject}; ]
    | 'x' ';'
    | '{' stmt* '}' ;
enter: [ ${state} = st_make(st_val(${state}) + 1); ] ;
leave: [ ${state} = st_make(st_val(${state}) - 1); ] ;

/* Two readings of 'a' set different modes; only the reading whose mode
   matches the tail survives, instead of the two being merged. */
mode_s: mode_a mode_tail ;
mode_a: mode_x | mode_y ;
mode_x: 'a' [ ${state} = st_make(1); ] { trace("x"); } ;
mode_y: 'a' [ ${state} = st_make(2); ] { trace("y"); } ;
mode_tail: 'p' [ if (st_val(${state}) != 1) ${reject}; ]
         | 'q' [ if (st_val(${state}) != 2) ${reject}; ] ;

/* The same, but the two readings are alternatives of one production, so
   they start from the same state and differ only in their actions' result. */
alt_s: alt_a mode_tail ;
alt_a: 'a' [ ${state} = st_make(1); ] { trace("x"); }
     | 'a' [ ${state} = st_make(2); ] { trace("y"); } ;

/* Two complete parses that end with different states. */
top_s: top_x | top_y ;
top_x: 'b' [ ${state} = st_make(1); ] { trace("x"); } ;
top_y: 'b' [ ${state} = st_make(2); ] { trace("y"); } ;

/* Two complete parses that end with the same state: an ordinary ambiguity. */
same_s: same_x | same_y ;
same_x: 'c' [ ${state} = st_make(1); ] { trace("x"); } ;
same_y: 'c' [ ${state} = st_make(1); ] { trace("y"); } ;

/* ${state N} is the state before child N; ${state} in a final action is the
   state after the node. */
child_s: 'd' child_set 'e'
  { trace(st_val(${state 0}) == 0 && st_val(${state 1}) == 0 && st_val(${state 2}) == 7 &&
          st_val(${state}) == 7 && st_val(d_get_state(&$n1)) == 7 ? "ok" : "bad"); } ;
child_set: [ ${state} = st_make(7); ] ;

/* A whitespace function that reads the state: '#' comments are allowed only
   after 'hash'.  The ::= terminal's action runs when 'hash' is shifted, so
   the whitespace right after it already sees the new state. */
ws_s: ws_item* ;
ws_item: HASH | 'w' ;
HASH ::= 'hash' [ ${state} = st_make(1); ] ;
