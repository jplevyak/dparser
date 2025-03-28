{
#include "d.h"

  char *my_ops = "+";
  void *my_ops_cache = NULL;
  int my_ops_scan(d_loc_t *loc, unsigned char *op_assoc, int *op_priority) {
    if (loc->s[0] == *my_ops) {
      my_ops_cache = (void*)loc->s;
      loc->s++;
      *op_assoc = ASSOC_BINARY_LEFT;
      *op_priority = 9500;
      return 1;
    }
    return 0;
  }
}

X: '1' (${scan my_ops_scan} '2')*;
