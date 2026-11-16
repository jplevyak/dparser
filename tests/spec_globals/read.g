{
struct G { int depth; int count; };
#define D_ParseNode_Globals struct G
}
/* Speculative actions may read the globals; final actions may write them. */
S: A+ { $g->count = $#0; } ;
A: 'a' [ if ($g && $g->depth > 10) ${reject}; ] ;
