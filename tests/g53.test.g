{
#include <stdio.h>
#include "dparse.h"
#include "dsymtab.h"
}

/* Two derivations of 'decl' cover the same text but declare different
   symbols.  They must not be merged into one ambiguous node, or the rest of
   the parse would continue with only one of the two symbol tables. */

S: decl ';' use ';';

decl
  : 'd' a1 [ SPECULATIVE_NEW_D_SYM(&${scope}, "p", 0); ] { printf("declared p\n"); }
  | 'd' a2 [ SPECULATIVE_NEW_D_SYM(&${scope}, "q", 0); ] { printf("declared q\n"); }
  ;
a1: 'a';
a2: 'a';

use: identifier [ if (!find_D_Sym(${scope}, $n0.start_loc.s, $n0.end)) ${reject}; ]
  { printf("used %.*s\n", (int)($n0.end - $n0.start_loc.s), $n0.start_loc.s); }
  ;

identifier: "[a-z]+";
