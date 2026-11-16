{
struct G { int depth; };
#define D_ParseNode_Globals struct G
}
/* Writing the globals from a speculative action must not compile. */
S: A+ ;
A: 'a' [ $g->depth++; ] ;
