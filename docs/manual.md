# DParser Manual


## Contents

* [Installation](#installation)
* [Getting Started](#getting-started)
* [Comments](#comments)
* [Productions](#productions)
* [Global Code](#global-code)
* [Terminals](#terminals)
* [Priorities and Associativity](#priorities-and-associativity)
* [Actions](#actions)
* [Attributes and Action Specifiers](#attributes-and-action-specifiers)
* [Symbol Table](#symbol-table)
* [Whitespace](#whitespace)
* [Ambiguities](#ambiguities)
* [Error Recovery](#error-recovery)
* [Parsing Options](#parsing-options)
* [Grammar Grammar](#grammar-grammar)


## Installation

* To build: `gmake` (only available with source code package)
* To test: `gmake test` (only available with source code package)
* To install: `gmake install` (binary or source code packages)


## Getting Started

1. Create your grammar, for example, in the file `my.g`:
```Yacc
E: E '+' E | "[abc]";
```
2. Convert grammar into parsing tables:
```Bash
$ make_dparser my.g
```
3. Create a driver program, for example, in the file `my.c`:
```C
    #include <stdio.h>
    #include <dparse.h>

    // Defined in file generated from grammar
    extern D_ParserTables parser_tables_gram;

    int main(int argc, char* argv[]) {
        char line[256];
        D_Parser* parser = new_D_Parser(&parser_tables_gram, 0);
        if (fgets(line, 255, stdin) && dparse(parser, line, strlen(line)) && !parser->syntax_errors)
            printf("success\n");
        else
            printf("failure\n");
        free_D_Parser(parser);
        return 0;
    }
```
4. Compile:
```Bash
$ cc -I/usr/local/include my.c my.g.d_parser.c -L/usr/local/lib -ldparse
```
5. Run:
```
    $ a.out
    a=
    syntax error, '' line 1
    failure
    $

    $ a.out
    a+b
    success
    $
```
We'll come back to this example later.
<!-- TODO did we ever come back to it? -->


## Comments

Grammars can include C/C++ style comments.  For example:
```Yacc
// My first grammar
E: E '+' E | "[abc]";
/* is this right? */
```


## Productions

* The first production is the root of your grammar (what you will be trying to
  parse).
* Productions start with the non-terminal being defined followed by a colon `:`
  and a set of right hand sides separated by `|` (`or`) consisting of elements
  (non-terminals or terminals).
* Elements can be grouped with parens `(` `)`, and the normal regular
  expression symbols can be used (`+` `*` `?` `|`).
* Elements can be repeated using `@`; for example `elem@3` or `elem@1:3` for
  repeating 3 or between 1 and 3 times respectively.

Example:
```Yacc
program: statements+ | comment* (function | procedure)?;
```

**NOTE**: Instead of using `[` `]` for optional elements we use the more
familar and consistent `?` operator.  The square brackets are reserved for
speculative actions (below).


## Global Code

Global (or static) C code can be intermixed with productions by surrounding the
code with braces `{` `}`.

Example:
```Yacc
{ void dr_s() { printf("Dr. S\n"); } }
S: 'the' 'cat' 'and' 'the' 'hat' { dr_s(); } | T;
{ void twain() { printf("Mark Twain\n"); }
T: 'Huck' 'Finn' { twain(); };
```


## Terminals

### Strings

String terminals are surrounded with single quotes.  For example:
```Yacc
block: '{' statements* '}';
whileblock: 'while' '(' expression ')' block;
```

### Unicode

Unicode literals can appear in strings or as charaters with `U+` or `u+`.  For
example:
```Yacc
'φ'      { printf("phi\n"); }
U+03c9   { printf("omega\n"); }
```

### Regular Expressions

Regular expressions are surrounded with double quotes.  For example:
```Yacc
hexint: "(0x|0X)[0-9a-fA-F]+[uUlL]?";
```

**NOTE**: Only the simple regular expression operators are currently supported.
These include parens `()`, square parens `[]`, ranges, and `*`, `+`,
`?`.  If you need something more, request a feature or implement it yourself;
the code is in `scan.c`.

### Terminal Modifiers

Terminals can contain embedded escape codes.  Including the standard C escape
codes, the codes `\x` and `\d` permit inserting hex and decimal ASCII
characters directly.

Tokens can be given a name by appending the `$name` option.  This is useful
when you have several tokens which which represent the same string (e.g. `,`).
For example:
```Yacc
function_call: function '(' parameter (',' $name 'parameter_comma' parameter) ')';
```

<!-- TODO clarify ParseNode ($0) vs ParseNode($0) -->
It is now possible to use `$0.symbol == ${string parameter_comma}` to
differentiate `ParseNode` (`$0`) between a parameter comma node and say an
initialization comma.

Terminals ending in `/i` are case insensitive.  For example, `'hi'/i` matches
`HI`, `Hi` and `hI` in addition to `hi`.

### External (C) Scanners

There are two types of external scanners, those which read a single terminal,
and those which are global (called for every terminal).  Here is an example of
a scanner for a single terminal.  Notice how it can be mixed with regular
string terminals.
```C
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
```
```Yacc
X: '1' (${scan ops_scan} '2')*;
```

The user provides the `ops_scan` function.  This example is from
`tests/g4.test.g` in the source distribution.

The second type of scanner is a global scanner:
```C
{
    #include "g7.test.g.d_parser.h"

    int myscanner(char **s, int *col, int *line,
                  unsigned short *symbol, int *term_priority,
                  unsigned short *op_assoc, int *op_priority)
    {
      switch (**s) {
        case 'a':
          (*s)++;
          *symbol = A;
          return 1;

        case 'b':
          (*s)++;
          *symbol = BB;
          return 1;

        case 'c':
          (*s)++;
          *symbol = CCC;
          return 1;

        case 'd':
          (*s)++;
          *symbol = DDDD;
          return 1;
    }

    return 0;
  }
}
```
```Yacc
${scanner myscanner}
${token A BB CCC DDDD}

S: A (BB CCC)+ SS;
SS: DDDD;
```

Notice how the you need to include the header file generated by `make_dparser`
which contains the token definitions.

### Tokenizers

Tokenizers are non-context sensitive global scanners which produce only one
token for any given input string.  Some programming languages (for example `C`)
are easier to specify using a tokenizer because (for example) reserved words
can be handled simply by lowering the terminal priority for identifiers.  For
example:
```Yacc
S : 'if' '(' S ')' S ';' | 'do' S 'while' '(' S ')' ';' | ident;
ident: "[a-z]+" $term -1;
```

The sentence `if ( while ) a;` is legal because `while` cannot appear at the
start of `S` and so it doesn't conflict with the parsing of `while` as an
`ident` in that position.  However, if a tokenizer is specified, all tokens
will be possible at each position and the sentence will produce a syntax error.

`DParser` provides two ways to specify tokenizers: globally as an option (`-T`)
to `make_dparser` and locally with a `${declare tokenize ...}` specifier (see
the ANSI C grammar for an example).  The `${declare tokenize ...}` declaration
allows a tokenizer to be specified over a subset of the parsing states so that
(for example) ANSI C could be a subgrammar of another larger grammar.
Currently the parse states are not split so that the productions for the
substates must be disjoint.

### Longest Match

Longest match lexical ambiguity resolution is a technique used by separate
phase lexers to help decide (along with lexical priorities) which single token
to select for a given input string.  It is used in the definition of ANSI-C,
but not in C++ because of a snafu in the definition of templates whereby
templates of templates (`List<List<Int>>`) can end with the right shift token
(`>>`).  Since `DParser` does not have a separate lexical phase, it does not
require longest match disambiguation, but provides it as an option.

There are two ways to specify longest match disabiguation: globally as an
option (`-l`) to `make_dparser` or locally with a `${declare longest_match
...}`.  If global longest match disambiguation is **ON**, it can be locally
disabled with a `{$declare all_matches ...}`.  As with Tokenizers above, local
declarations operate on disjoint subsets of parsing states.


## Priorities and Associativity

Priorities can vary from `MININT` to `MAXINT` and are specified as integers.

### Token Prioritites

Terminal priorities apply after the set of matching strings has been found and
the terminal(s) with the highest priority is selected.

Terminal priorities are introduced after a terminal by the specifier `$term`.
We saw an example of token priorities with the definition of `ident`. Another
example:
```Yacc
S : 'if' '(' S ')' S ';' | 'do' S 'while' '(' S ')' ';' | ident;
ident: "[a-z]+" $term -1;
```

### Operator Priorities

Operator priorities specify the priority of an operator symbol (either a
terminal or a non-terminal).  This corresponds to the `yacc` or `bison`
`%left`, `%right`, etc. declaration.  However, since `DParser` doesn't require
a global tokenizer, operator priorities and associativities are specified on
the reduction which creates the token.  Moreover, the associativity includes
the operator usage as well since it cannot be inferred from rule context.
Possible operator associativities are:
```Yacc
operator_assoc : '$unary_op_right'  | '$unary_op_left'
               | '$binary_op_right' | '$binary_op_left'
               ;
```
Example:
```Yacc
E: ident op ident;
ident: '[a-z]+';
op: '*' $binary_op_left 2 |
    '+' $binary_op_left 1 ;
```

### Rule Priorities

Rule priorities specify the priority of the reduction itself and have the
possible associativities:
```Yacc
rule_assoc: '$right' | '$left';
```

Example:
```Yacc
E: E '+' E $right 2 | E '*' E $right 1;
```

Rule and operator priorities can be intermixed and are interpreted at run time
(**not** when the tables are built).  This makes it possible for user-defined
scanners to return the associativities and priorities of tokens.

Note, for historical reasons, specific unary and binary operator associativities
can be provided, but these are not necessary as they will be inferred from the rule.

deprecated_rule_assoc
               : '$unary_right'     | '$unary_left'
               | '$binary_right'    | '$binary_left';

So for example:
```Yacc
E: '-' E $right 1 | E '+' E $left 2;
```

are equivalent to:

```Yacc
E: '-' E $unary_right 1 | E '+' E $binary_left 2;
```

### Ambiguity Resolution

Ambiguities are resolved by the following rules:

1. Local priorities and associativities are used to resolve ambiguities
for operators which are adjacent.  This suffices for most cases of simple
mathematical expressions.

2. If the above fails, all the ambiguous parse nodes are sorted by least height, then highest priority, then earliest start and then the priorites are compares pairwise in order. The first difference in priorities is used to resolve the ambiguity in favor of highest priority node's parse tree. This follows the intuition that the higher priority rules should be resolved first.  It may produce unintuitive results in cases where many different parses are possible and non-local high priority reductions result in lower priority reductions being selected later (higher) in the parse tree. Such cases may require restructuring the grammar.

3. If the above fails, the longest match is used to resolve the ambiguity.

4. If the above fails, smallest height is used to resolve the ambiguity.

5. If the above fails, any user defined ambiguity resolution function is called.

Note that these default ambiguity resolution rules can be overridden by flags and the default ambiguity resolution function will print out the ambiguous parse trees if the `verbose_level` flag is set after which it will abort.

e

## Actions

Actions are the bits of code which run when a reduction occurs.  For example:
```Yacc
S: this | that;
this: 'this' { printf("got this\n"); };
that: 'that' { printf("got that\n"); };
```

### Speculative Actions

Speculative actions occur when the reduction takes place during the speculative
parsing process.  It is possible that the reduction will not be part of the
final parse or that it will occur a different number of times.  For example:
```Yacc
S: this | that;
this: hi 'mom';
that: ho 'dad';
ho: 'hello' [ printf("ho\n"); ];
hi: 'hello' [ printf("hi\n"); ];
```
Will print both `hi` and `ho` when given the input `hello dad` because at the
time `hello` is reduced, the following token is not known.

### Final Actions

Final actions occur only when the reduction must be part of any legal final
parse (committed).  It is possible to do final actions during parsing or delay
them till the entire parse tree is constructed (see Options).  Final actions
are executed in order and in number according to the single final unambiguous
parse.  For example:
```Yacc
S: A S 'b' | 'x';
A: [ printf("speculative e-reduce A\n"); ]
   { printf("final e-reduce A\n"); };
```
On input `xbbb` will produce:
```
speculative e-reduce A   # is x an A? no, but it is an S
final e-reduce A         # b number 1 is an S
final e-reduce A         # b number 2 is an S
final e-reduce A         # b number 3 is an S
```

### Embedded Actions

Actions can be embedded into rules. These actions are executed as if they were
replaced with a synthetic production with a single null rule containing the
actions.  For example:
```Yacc
S:  A  { printf("X"); } B;
A: 'a' { printf("a"); };
B: 'b' { printf("b"); };
```
On input `ab` will produce:
```
aXb
```
Note that in the above example, the `printf("X")` is evaluated in a null rule
context, while in
```Yacc
S: A (A B { printf("X"); }) B;
```
the `printf` is evaluated in the context of the `A B` subrule because it
appears at the end of the subrule and is therefore treated as a normal action
for the subrule.

### Pass Actions

`DParser` supports multiple pass compilation.  The passes are declared at the
top of the grammar, and the actions are associated with individual rules.  For
example:
```Yacc
${pass sym for_all postorder}
${pass gen for_all postorder}

translation_unit: statement*;

statement:
  expression ';' {
    d_pass(${parser}, &$n, ${pass sym});
    d_pass(${parser}, &$n, ${pass gen});
  }
  ;

expression:
  integer
      gen: { printf("gen integer\n"); }
      sym: { printf("sym integer\n"); }
  | expression '+' expression $right 2
      sym: { printf("sym +\n"); }
  ;
```
A pass name then a colon indicate that the following action is associated with
a particular pass.  Passes can be either `for_all` or `for_undefined` (which
means that the automatic traversal only applies to rules without actions
defined for this pass).  Furthermore, passes can be `postorder`, `preorder`,
and `manual` (you have to call `d_pass` yourself).  Passes can be initiated in
the final action of any rule.

### Default Actions

The special production `_` can be defined with a single rule whose actions
become the default when no other action is specified.  Default actions can be
specified for speculative, final and pass actions and apply to each separately.
For example:
```Yacc
_: { printf("final action"); }
    gen: { printf("default gen action"); }
    sym: { printf("default sym action"); }
  ;
```


## Attributes and Action Specifiers

### Global State (`$g`)

Global state is declared by `#define`ing `D_ParseNode_Globals` (see the ANSI C
grammar for a similar declaration for symbols). Global state can be accessed in
any action with `$g`.  Because `DParser` handles ambiguous parsing, global
state can be accessed on different speculative parses.  In the future,
automatic splitting of global state may be implemented (if there is demand).

The symbol table can be used to manage state information safely for different
speculative parses.

### Parse Node State

Each parse node includes a set of system state variables and can have a set of
user-defined state variables.  User defined parse node state is declared by
`#define`ing `D_ParseNodeUser`.  The size of the parse node state must be
passed into `new_D_Parser()` to ensure that the appropriate amount of space is
allocated for parse nodes.  Parse node state is accessed with:
* `$#` - number of child nodes
* `$$` - user parse node state for parent node (non-terminal defined by the production)
* `$X` (where X is a number) - the user parse node state of element X of the production
* `$n` - the system parse node state of the rule node
* `$nX` (where X is a number) - the system parse node state of element X of the production

The system parse node state is defined in `dparse.h` which is installed with
`DParser`.  It contains such information as the symbol, the location of the
parsed string, and pointers to the start and end of the parsed string.

### Miscellaneous

* `${scope}` - the current symbol table scope
* `${reject}` - in speculative actions permits the current parse to be rejected


## Symbol Table

The symbol table can be updated down different speculative paths while sharing
the bulk of the data.  It defines the following functions in the file
`dsymtab.h`:
```C
struct D_Scope *new_D_Scope(struct D_Scope *st);
struct D_Scope *enter_D_Scope(struct D_Scope *current, struct D_Scope *scope);
D_Sym *NEW_D_SYM(struct D_Scope *st, char *name, char *end);
D_Sym *find_D_Sym(struct D_Scope *st, char *name, char *end);
D_Sym *UPDATE_D_SYM(struct D_Scope *st, D_Sym *sym);
D_Sym *current_D_Sym(struct D_Scope *st, D_Sym *sym);
D_Sym *find_D_Sym_in_Scope(struct D_Scope *st, char *name, char *end);
```
<!-- TODO check if commit_D_Scope should actually be NEW_D_SYM -->
* `new_D_Scope` creates a new scope below `st`, or `NULL` for a 'top level'
  scope.
* `enter_D_Scope` returns to a previous scoping level.  **NOTE**: do not simply
  assign `${scope}` to a previous scope as any updated symbol information will
  be lost.
* `commit_D_Scope` can be used in final actions to compress the update list for
  the top level scope and improve efficiency.
* `find_D_Sym` finds the most current version of a symbol in a given scope.
* `UPDATE_D_SYM` updates the value of symbol (creates a different record on the
  current speculative parse path).
* `current_D_Sym` is used to retrieve the current version of a symbol, the
  pointer to which may have been stored in some other attribute or variable.

Symbols with the same name should not be created in the same scope.  The
function `find_D_Sym_in_Scope` is provided to detect this case.

User data can be attached to symbols by `#define`ing `D_UserSym`.  See the ANSI
C grammar for an example.

Here is a full example of scope usage (from `tests/g29.test.g`):
```C
{
    #include <stdio.h>

    typedef struct My_Sym {
      int value;
    } My_Sym;
    #define D_UserSym My_Sym

    typedef struct My_ParseNode {
      int value;
      struct D_Scope *scope;
    } My_ParseNode;
    #define D_ParseNode_User My_ParseNode
}
```
```Yacc
translation_unit: statement*;

statement:
    expression ';'
        { printf("%d\n", $0.value); }
  | '{' new_scope statement* '}'
        [ ${scope} = enter_D_Scope(${scope}, $n0.scope); ]
        { ${scope} = commit_D_Scope(${scope}); }
  ;

new_scope: [ ${scope} = new_D_Scope(${scope}); ];

expression:
    identifier ':' expression
        [
          D_Sym *s;
          if (find_D_Sym_in_Scope(${scope}, $n0.start_loc.s, $n0.end))
            printf("duplicate identifier line %d\n", $n0.start_loc.line);
          s = NEW_D_SYM(${scope}, $n0.start_loc.s, $n0.end);
          s->user.value = $2.value;
          $$.value = s->user.value;
        ]
  | identifier '=' expression
        [
          D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
          s = UPDATE_D_SYM(${scope}, s);
          s->user.value = $2.value;
          $$.value = s->user.value;
        ]
  | integer
        [ $$.value = atoi($n0.start_loc.s); ]
  | identifier
        [
          D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
          if (s)
            $$.value = s->user.value;
        ]
  | expression '+' expression
        [ $$.value = $0.value + $1.value; ]
  ;

integer: "-?([0-9]|0(x|X))[0-9]*(u|U|b|B|w|W|L|l)*" $term -1;
identifier: "[_a-zA-Z][a-zA-Z_0-9]*";
```


## Whitespace

Whitespace can be specified in two ways: as a C function which can be
user-defined, or as a subgrammar.  The default whitespace parser is compatible
with C/C++ `#line` directives and comments.  It can be replaced with any user
specified function as a parsing option (see Options).

Additionally, if the (optionally) reserved production `whitespace` is defined,
the subgrammar it defines will be used to consume whitespace for the main
grammar.  This subgrammar can include normal actions.  For example:
```Yacc
S: 'a' 'b' 'c';
whitespace: "[ \t\n]*";
```

Whitespace can be accessed on a per parse node basis using the functions
`d_ws_before` and `d_ws_after`, which return the start of the whitespace before
`start_loc.s` and after `end`, respectively.


## Ambiguities

Ambiguities are resolved automatically based on priorities and associativities.
In addition, when the other resolution techniques fail, user defined ambiguity
resolution is possible.  The default ambiguity handler produces a fatal error
on an unresolved ambiguity.  This behavior can be replaced with a user defined
resolver, the signature of which is provided in `dparse.h`.

If the `verbose_level` flag is set, the default ambiguity handler will print
out parenthesized versions of the ambiguous parse trees.  This may be of some
assistance in disambiguating a grammar.


## Error Recovery

`DParser` implements an error recovery scheme appropriate to scannerless
parsers.  I haven't had time to investigate all the prior work in this area, so
I am not sure if it is novel.  Suffice to say for now that it is optional and
works well with C/C++ like grammars.


## Parsing Options

Parsers are instantiated with the function `new_D_Parser`.  The resulting data
structure contains a number of user configurable options (see `dparser.h`).
These are provided reasonable default values and include:
* `initial_globals` - the initial global variables accessable through `$g`
* `initial_skip_space_fn` - the initial whitespace function
* `initial_scope` - the initial symbol table scope
* `syntax_error_fn` - the function called on a syntax error
* `ambiguity_fn` - the function called on an unresolved ambiguity
* `loc` - the initial location (set on an error)

In addition, there are the following user configurables:

* `sizeof_user_parse_node` - the size of `D_ParseNodeUser`
* `save_parse_tree` - whether or not the parse tree should be saved once the
  final actions have been executed
* `dont_fixup_internal_productions` - to not convert the Kleene star into a
  variable number of children from a tree of reductions
* `dont_merge_epsilon_trees` - to not automatically remove ambiguities which
  result from trees of epsilon reductions without actions
* `dont_use_greediness_for_disambiguation` - do not use the rule that the
  longest parse which reduces to the same token should be used to disambiguate
  parses; this rule is used to handle the case (`if then else?`) relatively
  cleanly
* `dont_use_height_for_disambiguation` - do not use the rule that the least
  deep parse which reduces to the same token should be used to disambiguate
  parses; this rule is used to handle recursive grammars relatively cleanly
* `dont_compare_stacks` - disables comparing stacks to handle certain
  exponential cases during ambiguous operator priority resolution
* `commit_actions_interval` - how often to commit final actions (`0` is
  immediate, `MAXINT` is essentially not till the end of parsing)
* `error_recovery` - whether or not to use error recovery (defaults to `ON`)

And the following result values:
* `syntax_errors` - how many syntax errors (if `error_recovery` was on); this
  final value should be checked to see if the parse was successful


## Grammar Grammar
<!-- TODO why "Grammar Grammar"? Why not "DParser Grammar"? -->

`DParser` is fully self-hosted (would you trust a parser generator which
wasn't?).  The grammar grammar is in `grammar.g`.
