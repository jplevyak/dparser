/* Grammar for test_bounds.c: buffers that are not NUL-terminated. */
program: stmt* ;
stmt: expr ';' ;
expr: expr '+' expr $left 1 | "[a-z]+" ;
