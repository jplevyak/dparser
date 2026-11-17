/* make_dparser leaves $ alone in comments and in string and character
   literals, and character literals may hold brackets: ${scope} here. */
{
#include <stdio.h>
// a comment with ${state} and $g
static const char *price = "costs $5 {";  /* a string with $ and { */
static const char open = '{', close_ = '}', quote = '\'', dollar = '$';
static int s_symbol = ${nterm S};
}

S: item+ ;
item: "[a-z]+" {
  /* ${not_a_specifier} in an action's comment */
  char paren = ')';  // and ')' here
  printf("%.*s %s %c%c%c%c%c %d\n", (int)($n0.end - $n0.start_loc.s), $n0.start_loc.s,
         price, open, close_, quote, dollar, paren, s_symbol);
} ;
