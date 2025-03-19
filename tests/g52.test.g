S: E;

E: T
 | E '+' E $binary_left 1
 | E '-' E $binary_left 2
 | E '*' E $binary_left 3
 | E '/' E $binary_left 4
 | '-' E $unary_right 5
 ;

T: "[1-9]";
