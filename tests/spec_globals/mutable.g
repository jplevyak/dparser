{
struct G { int depth; };
#define D_ParseNode_Globals struct G
}
${declare mutable_speculative_globals}
/* With the declaration, speculative actions may write the globals again. */
S: A+ ;
A: 'a' [ $g->depth++; ] ;
