expr: 'x'
    | '-' expr $unary_right 3
    | '!' expr $unary_right 1
    | expr '+' expr $binary_right 2
    ;
