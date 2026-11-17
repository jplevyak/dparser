/* Grammar for test_state.c: whitespace productions read ${state}.
   '#' comments are whitespace only after 'hash'. */
{
void *st_make(int v);
int st_val(void *s);
}

S: item* ;
item: HASH | 'w' ;
HASH ::= 'hash' [ ${state} = st_make(1); ] ;

whitespace: ( "[ \t\n]+" | comment )* ;
comment: '#' "[^\n]*" [ if (st_val(${state}) != 1) ${reject}; ] ;
